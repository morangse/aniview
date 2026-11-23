import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/secure_vault.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/media.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/source_adapters.dart';
import '../../media/sources/source_models.dart';
import '../anime/anime.dart';
import 'player_controls_bar.dart';

typedef InPlayerLaunch = ({
  MediaCandidate candidate,
  PlaybackSession? session,
});

typedef InPlayerSourceSnapshot = ({
  MediaSearchRequest request,
  FetchResult result,
  bool episodeUnknown,
  bool done,
  String? rememberedSourceId,
});

class PlayerResolveArgs {
  const PlayerResolveArgs({
    required this.request,
    this.autoPlay = true,
    this.forceShowSources = false,
    this.resumeAt,
    this.previousDuration,
  });

  final MediaSearchRequest request;
  final bool autoPlay;
  final bool forceShowSources;
  final Duration? resumeAt;
  final Duration? previousDuration;
}

class InPlayerSourceHelper {
  const InPlayerSourceHelper._();

  static Future<({MediaSearchRequest request, bool episodeUnknown})>
  resolveTargetRequest({
    required MediaResolver resolver,
    required AnimeRepository catalog,
    required MediaSearchRequest baseRequest,
  }) async {
    var request = baseRequest;
    final anime = request.anime;
    final episodic =
        anime != null &&
        !const {
          '剧场版',
          '电影',
          'movie',
          'film',
        }.contains(anime.platform.toLowerCase());
    if (episodic && request.episode == null) {
      try {
        final catalogEpisodes = await catalog.episodes(anime.id);
        Episode? first;
        for (final episode in catalogEpisodes.value) {
          if (episode.kind == EpisodeKind.regular &&
              (first == null || episode.number < first.number)) {
            first = episode;
          }
        }
        request = MediaSearchRequest(anime: anime, episode: first);
      } on Exception {
        // Leave episode null so the user can manually select a source or retry.
      }
    }
    return (
      request: request,
      episodeUnknown: episodic && request.episode == null,
    );
  }

  static Future<InPlayerLaunch?> pickLocalVideo({
    required MediaResolver resolver,
    required MediaSearchRequest request,
    Duration? resumeAt,
    Duration? previousDuration,
  }) async {
    await resolver.registry.enabledAdapter('local');
    final file = await const AndroidMediaAccess().pickVideo();
    if (file == null) return null;
    final candidate = MediaCandidate.create(
      uri: file.uri,
      kind: MediaKind.document,
      sourceName: file.name,
      request: request,
    );
    await resolver.library.addMedia(candidate);
    final session = resumeAt == null
        ? null
        : (PlaybackSession(request, const [])
            ..resumeAt = resumeAt
            ..previousDuration = previousDuration);
    return (candidate: candidate, session: session);
  }

  static Future<InPlayerLaunch> saveDirectAddress({
    required MediaResolver resolver,
    required MediaSearchRequest request,
    required String rawAddress,
    Duration? resumeAt,
    Duration? previousDuration,
  }) async {
    final uri = parsePlaybackUrl(rawAddress);
    if (uri.hasQuery && !uri.isScheme('https')) serverEndpoint(uri.origin);
    final label = uri.pathSegments.lastOrNull;
    final name = label == null || label.isEmpty ? uri.host : label;
    final id = randomIdentifier(16);
    await resolver.store.put(
      ConfiguredSource(
        id: id,
        name: name,
        kind: 'direct',
        endpoint: uri.origin,
        userId: '',
        enabled: true,
        priority: 0,
        offlineAllowed: false,
        subjectTitle: request.anime?.title ?? '',
        subjectId: request.anime?.id,
        episodeId: request.episode?.id,
      ),
      secret: {'url': uri.toString(), 'headers': <String, String>{}},
    );
    final offer = SourceOffer(sourceId: id, resourceId: id, label: name);
    final session = PlaybackSession(request, const [], selected: offer)
      ..resumeAt = resumeAt
      ..previousDuration = previousDuration;
    session.next();
    return (
      candidate: await resolver.save(request, offer),
      session: session,
    );
  }
}

class PlayerResolveScreen extends ConsumerStatefulWidget {
  const PlayerResolveScreen({super.key, required this.args});

  final PlayerResolveArgs args;

  @override
  ConsumerState<PlayerResolveScreen> createState() =>
      _PlayerResolveScreenState();
}

class _PlayerResolveScreenState extends ConsumerState<PlayerResolveScreen> {
  StreamSubscription<InPlayerSourceSnapshot>? _subscription;
  InPlayerSourceSnapshot? _snapshot;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _startLookup(fromInit: true);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  void _startLookup({bool fromInit = false}) {
    unawaited(_subscription?.cancel());
    _launched = false;
    if (fromInit) {
      _snapshot = null;
    } else {
      setState(() => _snapshot = null);
    }
    _subscription = _watch().listen((snap) {
      if (!mounted) return;
      setState(() => _snapshot = snap);
      if (widget.args.autoPlay &&
          !widget.args.forceShowSources &&
          !snap.episodeUnknown &&
          !_launched &&
          snap.result.offers.any(PlaybackSession.canSelectAutomatically)) {
        unawaited(_autoLaunch(snap));
      }
    });
  }

  Stream<InPlayerSourceSnapshot> _watch() async* {
    final resolver = ref.read(resolverProvider);
    final catalog = ref.read(animeRepositoryProvider);
    final resolved = await InPlayerSourceHelper.resolveTargetRequest(
      resolver: resolver,
      catalog: catalog,
      baseRequest: widget.args.request,
    );
    final remembered = await resolver.verifiedSource(resolved.request.anime?.id);

    yield (
      request: resolved.request,
      result: const FetchResult([], {}),
      episodeUnknown: resolved.episodeUnknown,
      done: false,
      rememberedSourceId: remembered,
    );

    final useFastPath = widget.args.autoPlay && !widget.args.forceShowSources;
    var lastResult = const FetchResult([], {});
    await for (final result in (useFastPath
        ? resolver.watch(resolved.request)
        : resolver.watchAll(resolved.request))) {
      lastResult = result;
      yield (
        request: resolved.request,
        result: result,
        episodeUnknown: resolved.episodeUnknown,
        done: false,
        rememberedSourceId: remembered,
      );
    }

    yield (
      request: resolved.request,
      result: lastResult,
      episodeUnknown: resolved.episodeUnknown,
      done: true,
      rememberedSourceId: remembered,
    );
  }

  Future<void> _autoLaunch(InPlayerSourceSnapshot snap) async {
    if (_launched || !mounted) return;
    _launched = true;
    final resolver = ref.read(resolverProvider);
    unawaited(_subscription?.cancel());
    _subscription = null;

    final session =
        PlaybackSession(snap.request, snap.result.offers)
          ..resumeAt = widget.args.resumeAt
          ..previousDuration = widget.args.previousDuration;
    final first = session.next();
    if (first == null) {
      if (mounted) setState(() => _launched = false);
      return;
    }
    try {
      final candidate = await resolver.save(snap.request, first);
      if (!mounted) return;
      context.replace('/player/${candidate.id}', extra: session);
    } on Exception {
      if (mounted) setState(() => _launched = false);
    }
  }

  void _openLaunch(InPlayerLaunch launch) {
    if (_launched || !mounted) return;
    _launched = true;
    unawaited(_subscription?.cancel());
    context.replace('/player/${launch.candidate.id}', extra: launch.session);
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    final request = snap?.request ?? widget.args.request;
    final anime = request.anime;
    final episode = request.episode;
    final heroUri = anime?.poster ?? anime?.cover;
    final done = snap?.done ?? false;
    final hasOffers = snap?.result.offers.isNotEmpty ?? false;
    final remembered = snap?.rememberedSourceId != null;

    final viewport = ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black),
          if (heroUri != null)
            Opacity(
              opacity: 0.42,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Artwork(uri: heroUri, decodeWidth: 480),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x88000000), Color(0xCC0A111A)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.sm),
                child: LiquidGlassCircleButton(
                  key: const ValueKey('resolve-back-button'),
                  icon: Icons.arrow_back_ios_new_rounded,
                  label: '返回',
                  size: 38,
                  iconSize: 17,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!done)
                    const CircularProgressIndicator(
                      color: Color(0xFF6BB5FF),
                      semanticsLabel: '正在查找可播放片源',
                    )
                  else
                    Icon(
                      hasOffers
                          ? Icons.playlist_play_rounded
                          : Icons.video_library_outlined,
                      size: 36,
                      color: Colors.white70,
                    ),
                  const SizedBox(height: SpacingTokens.sm),
                  Text(
                    !done
                        ? (remembered ? '正在从已记住片源无缝加载…' : '正在查找可播放片源…')
                        : (hasOffers ? '请在片源区选择线路播放' : '未自动匹配到可用片源'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (anime != null || episode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        ?anime?.title,
                        ?episode?.label,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (done) ...[
                    const SizedBox(height: SpacingTokens.xs),
                    SoftButton(
                      label: '重新查找',
                      style: SoftStyle.outline,
                      onPressed: _startLookup,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final episodes = anime == null
        ? null
        : ref.watch(episodesProvider(anime.id)).value?.value;

    final details = ListView(
      padding: const EdgeInsets.all(SpacingTokens.md),
      children: [
        if (anime != null) ...[
          Text(anime.title, style: Theme.of(context).textTheme.titleLarge),
          if (episode != null) ...[
            const SizedBox(height: 2),
            Text(
              episode.title.isEmpty
                  ? episode.label
                  : '${episode.label} · ${episode.title}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ColorTokens.accent,
              ),
            ),
          ],
          const SizedBox(height: SpacingTokens.md),
        ],
        InPlayerSourcePanel(
          request: request,
          snapshot: snap,
          resumeAt: widget.args.resumeAt,
          previousDuration: widget.args.previousDuration,
          onRetry: _startLookup,
          onLaunch: _openLaunch,
        ),
        if (episodes != null && episodes.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.lg),
          const SectionHeading('切换剧集'),
          const SizedBox(height: SpacingTokens.xs),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: SpacingTokens.xs),
              itemBuilder: (_, index) {
                final ep = episodes[index];
                final current = ep.id == episode?.id;
                return SoftButton(
                  label: ep.label,
                  selected: current,
                  style: current ? SoftStyle.accent : SoftStyle.outline,
                  onPressed: () {
                    if (current) return;
                    context.replace(
                      '/player/resolve',
                      extra: PlayerResolveArgs(
                        request: MediaSearchRequest(anime: anime, episode: ep),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );

    return PlayerScreenScaffold(
      full: false,
      fullScreen: false,
      onExitFullscreen: () {},
      viewport: viewport,
      details: details,
    );
  }
}

class InPlayerSourcePanel extends ConsumerStatefulWidget {
  const InPlayerSourcePanel({
    super.key,
    required this.request,
    this.snapshot,
    this.resumeAt,
    this.previousDuration,
    this.onRetry,
    this.onLaunch,
  });

  final MediaSearchRequest request;
  final InPlayerSourceSnapshot? snapshot;
  final Duration? resumeAt;
  final Duration? previousDuration;
  final VoidCallback? onRetry;
  final ValueChanged<InPlayerLaunch>? onLaunch;

  @override
  ConsumerState<InPlayerSourcePanel> createState() =>
      _InPlayerSourcePanelState();
}

class _InPlayerSourcePanelState extends ConsumerState<InPlayerSourcePanel> {
  final _address = TextEditingController();
  StreamSubscription<InPlayerSourceSnapshot>? _subscription;
  InPlayerSourceSnapshot? _internalSnapshot;
  String? _fansubFilter;
  String? _resolutionFilter;
  bool _busy = false;
  bool _showManualAddress = false;
  String? _error;

  bool get _selfManaged => widget.snapshot == null;

  @override
  void initState() {
    super.initState();
    if (_selfManaged) _loadInternal(emitRebuild: false);
  }

  @override
  void didUpdateWidget(InPlayerSourcePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot != null) {
      unawaited(_subscription?.cancel());
      _subscription = null;
    } else if (oldWidget.snapshot != null ||
        oldWidget.request.episodeKey != widget.request.episodeKey) {
      _loadInternal(emitRebuild: false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _address.dispose();
    super.dispose();
  }

  void _loadInternal({bool emitRebuild = true}) {
    unawaited(_subscription?.cancel());
    if (emitRebuild) {
      setState(() => _internalSnapshot = null);
    } else {
      _internalSnapshot = null;
    }
    _subscription = _watchInternal().listen((snap) {
      if (mounted) setState(() => _internalSnapshot = snap);
    });
  }

  Stream<InPlayerSourceSnapshot> _watchInternal() async* {
    final resolver = ref.read(resolverProvider);
    final catalog = ref.read(animeRepositoryProvider);
    final resolved = await InPlayerSourceHelper.resolveTargetRequest(
      resolver: resolver,
      catalog: catalog,
      baseRequest: widget.request,
    );
    final remembered = await resolver.verifiedSource(resolved.request.anime?.id);

    yield (
      request: resolved.request,
      result: const FetchResult([], {}),
      episodeUnknown: resolved.episodeUnknown,
      done: false,
      rememberedSourceId: remembered,
    );

    var lastResult = const FetchResult([], {});
    await for (final result in resolver.watchAll(resolved.request)) {
      lastResult = result;
      yield (
        request: resolved.request,
        result: result,
        episodeUnknown: resolved.episodeUnknown,
        done: false,
        rememberedSourceId: remembered,
      );
    }

    yield (
      request: resolved.request,
      result: lastResult,
      episodeUnknown: resolved.episodeUnknown,
      done: true,
      rememberedSourceId: remembered,
    );
  }

  Future<void> _pickOffer(
    InPlayerSourceSnapshot snap,
    RankedOffer? entry,
  ) async {
    final session =
        PlaybackSession(
            snap.request,
            snap.episodeUnknown ? const [] : snap.result.offers,
            selected: entry?.offer,
          )
          ..resumeAt = widget.resumeAt
          ..previousDuration = widget.previousDuration;
    final first = session.next();
    if (first == null) return;
    await _runLaunch(() async {
      final resolver = ref.read(resolverProvider);
      if (entry != null && !entry.match.verified && !snap.episodeUnknown) {
        await resolver.confirm(snap.request, entry.offer);
      }
      return (
        candidate: await resolver.save(snap.request, first),
        session: session,
      );
    });
  }

  Future<void> _pickLocalOrUrl(
    MediaSearchRequest request, {
    required bool local,
  }) => _runLaunch(() async {
    final resolver = ref.read(resolverProvider);
    if (local) {
      return InPlayerSourceHelper.pickLocalVideo(
        resolver: resolver,
        request: request,
        resumeAt: widget.resumeAt,
        previousDuration: widget.previousDuration,
      );
    }
    return InPlayerSourceHelper.saveDirectAddress(
      resolver: resolver,
      request: request,
      rawAddress: _address.text,
      resumeAt: widget.resumeAt,
      previousDuration: widget.previousDuration,
    );
  });

  Future<void> _runLaunch(Future<InPlayerLaunch?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final launch = await action();
      if (!mounted || launch == null) return;
      if (widget.onLaunch case final callback?) {
        callback(launch);
      } else {
        context.replace('/player/${launch.candidate.id}', extra: launch.session);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SourceIssue catch (error) {
      if (mounted) setState(() => _error = error.label);
    } on Exception {
      if (mounted) setState(() => _error = '无法读取或保存片源，请检查网络或文件权限。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot ?? _internalSnapshot;
    final request = snap?.request ?? widget.request;
    final type = Theme.of(context).textTheme;
    final offers = snap?.result.offers ?? const <RankedOffer>[];
    final diagnostics = snap?.result.diagnostics ?? const <String, SourceIssue>{};
    final done = snap?.done ?? false;
    final rememberedId = snap?.rememberedSourceId;

    final fansubs = <String>{for (final o in offers) ?o.match.fansub}.toList();
    final resolutions = <String>{
      for (final o in offers) ?o.match.resolution,
    }.toList();
    final activeFansub = fansubs.contains(_fansubFilter) ? _fansubFilter : null;
    final activeRes = resolutions.contains(_resolutionFilter)
        ? _resolutionFilter
        : null;
    final visible = offers
        .where(
          (o) =>
              (activeFansub == null || o.match.fansub == activeFansub) &&
              (activeRes == null || o.match.resolution == activeRes),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading('片源选择')),
            TextButton.icon(
              onPressed: _busy ? null : (widget.onRetry ?? _loadInternal),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('刷新'),
            ),
          ],
        ),
        if (!done) ...[
          const SizedBox(height: SpacingTokens.xxs),
          const LinearProgressIndicator(semanticsLabel: '正在查询片源'),
          const SizedBox(height: SpacingTokens.xs),
        ],
        if (fansubs.length >= 2 || resolutions.length >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final sub in fansubs)
                    Padding(
                      padding: const EdgeInsets.only(right: SpacingTokens.xs),
                      child: FilterChip(
                        label: Text(sub),
                        selected: activeFansub == sub,
                        onSelected: (sel) =>
                            setState(() => _fansubFilter = sel ? sub : null),
                      ),
                    ),
                  for (final res in resolutions)
                    Padding(
                      padding: const EdgeInsets.only(right: SpacingTokens.xs),
                      child: FilterChip(
                        label: Text(res),
                        selected: activeRes == res,
                        onSelected: (sel) => setState(
                          () => _resolutionFilter = sel ? res : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (done && offers.isEmpty)
          StatusPanel(
            icon: Icons.video_library_outlined,
            title: '暂无自动匹配片源',
            message: '可在「管理片源」中添加订阅源，或直接选择本地文件 / 粘贴地址播放。',
            action: '管理片源',
            onAction: _busy ? null : () => context.push('/sources'),
          )
        else
          for (final entry in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
              child: Panel(
                child: InkWell(
                  key: ValueKey('inplayer-offer-${entry.offer.key}'),
                  onTap: _busy || snap == null
                      ? null
                      : () => _pickOffer(snap, entry),
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          entry.match.verified
                              ? Icons.verified_rounded
                              : Icons.play_circle_outline_rounded,
                          color: entry.match.verified
                              ? const Color(0xFF6BB5FF)
                              : ColorTokens.muted,
                          size: 20,
                        ),
                        const SizedBox(width: SpacingTokens.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.offer.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: type.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (rememberedId == entry.offer.sourceId)
                                    const _InPlayerTag('已记住片源', accent: true),
                                  _InPlayerTag(
                                    '${entry.health.label} · ${entry.match.score}%',
                                    accent: entry.match.verified,
                                  ),
                                  for (final tag in entry.match.tags)
                                    _InPlayerTag(tag),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.match.reason,
                                style: type.bodySmall?.copyWith(
                                  color: ColorTokens.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        for (final issue in diagnostics.entries)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${issue.key} · ${issue.value.label}',
              style: type.bodySmall,
            ),
          ),
        const SizedBox(height: SpacingTokens.xs),
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          children: [
            SoftButton(
              label: '本地视频',
              icon: Icons.folder_open_rounded,
              style: SoftStyle.outline,
              onPressed: _busy
                  ? null
                  : () => _pickLocalOrUrl(request, local: true),
            ),
            SoftButton(
              label: _showManualAddress ? '收起地址输入' : '粘贴播放地址',
              icon: Icons.link_rounded,
              style: SoftStyle.outline,
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _showManualAddress = !_showManualAddress,
                    ),
            ),
          ],
        ),
        if (_showManualAddress) ...[
          const SizedBox(height: SpacingTokens.sm),
          TextField(
            controller: _address,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _pickLocalOrUrl(request, local: false),
            decoration: InputDecoration(
              labelText: 'MP4 或 HLS 地址',
              helperText: '请输入你有权访问的视频地址。',
              errorText: _error,
              prefixIcon: const Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          SoftButton(
            label: '添加并播放',
            icon: Icons.play_arrow_rounded,
            style: SoftStyle.accent,
            onPressed: _busy
                ? null
                : () => _pickLocalOrUrl(request, local: false),
          ),
        ] else if (_error != null) ...[
          const SizedBox(height: SpacingTokens.xs),
          Text(_error!, style: type.bodySmall?.copyWith(color: ColorTokens.accent)),
        ],
      ],
    );
  }
}

class _InPlayerTag extends StatelessWidget {
  const _InPlayerTag(this.text, {this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent
          ? const Color(0x2A6BB5FF)
          : ColorTokens.shadow.withValues(alpha: 0.72),
      borderRadius: RadiusTokens.pill,
      border: Border.all(
        color: accent
            ? const Color(0x886BB5FF)
            : ColorTokens.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent ? const Color(0xFF9CD0FF) : ColorTokens.muted,
        ),
      ),
    ),
  );
}
