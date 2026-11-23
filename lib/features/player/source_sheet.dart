import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/secure_vault.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/media.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/source_adapters.dart';
import '../../media/sources/source_models.dart';
import '../anime/anime.dart';

typedef _PlaybackLaunch = ({
  MediaCandidate candidate,
  PlaybackSession? session,
});

typedef _SourceLookup = ({
  MediaSearchRequest request,
  FetchResult result,
  bool episodeUnknown,
  bool done,
});

Future<void> showSources(
  BuildContext context, {
  MediaRequest request = const MediaRequest(),
  bool autoStart = false,
  bool replacePlayer = false,
  Duration? resumeAt,
  Duration? previousDuration,
}) async {
  final router = GoRouter.of(context);
  final origin = router.routerDelegate.currentConfiguration;
  final media = await showModalBottomSheet<_PlaybackLaunch>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    requestFocus: false,
    sheetAnimationStyle: MotionTokens.sheetStyle(context),
    builder: (_) => _SourceSheet(
      request: MediaSearchRequest.from(request),
      autoStart: autoStart,
      resumeAt: resumeAt,
      previousDuration: previousDuration,
    ),
  );
  if (context.mounted &&
      media != null &&
      identical(origin, router.routerDelegate.currentConfiguration)) {
    final location = '/player/${media.candidate.id}';
    if (replacePlayer) {
      context.replace(location, extra: media.session);
    } else {
      await context.push<void>(location, extra: media.session);
    }
  }
}

Future<void> playAutomatically(BuildContext context, MediaRequest request) =>
    showSources(context, request: request, autoStart: true);

class _SourceSheet extends ConsumerStatefulWidget {
  const _SourceSheet({
    required this.request,
    required this.autoStart,
    this.resumeAt,
    this.previousDuration,
  });
  final MediaSearchRequest request;
  final bool autoStart;
  final Duration? resumeAt;
  final Duration? previousDuration;

  @override
  ConsumerState<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends ConsumerState<_SourceSheet> {
  final _address = TextEditingController();
  StreamSubscription<_SourceLookup>? _subscription;
  Completer<_SourceLookup?>? _autoCompleter;
  _SourceLookup? _lookup;
  String? _fansubFilter;
  String? _resolutionFilter;
  bool _autoPending = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _subscription?.cancel();
    setState(() {
      _lookup = null;
      _autoPending = widget.autoStart;
    });
    final stream = _watch();
    if (_autoPending) {
      unawaited(_auto(stream));
    } else {
      _subscription = stream.listen(
        (lookup) {
          if (mounted) setState(() => _lookup = lookup);
        },
      );
    }
  }

  Stream<_SourceLookup> _watch() async* {
    final resolver = ref.read(resolverProvider);
    var request = widget.request;
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
        final catalog = await ref
            .read(animeRepositoryProvider)
            .episodes(anime.id);
        Episode? first;
        for (final episode in catalog.value) {
          if (episode.kind == EpisodeKind.regular &&
              (first == null || episode.number < first.number)) {
            first = episode;
          }
        }
        request = MediaSearchRequest(anime: anime, episode: first);
      } on Exception {
        // Let the user retry or choose an explicitly known resource.
      }
    }

    yield (
      request: request,
      result: const FetchResult([], {}),
      episodeUnknown: episodic && request.episode == null,
      done: false,
    );

    var lastResult = const FetchResult([], {});
    await for (final result in resolver.watch(request)) {
      lastResult = result;
      yield (
        request: request,
        result: result,
        episodeUnknown: episodic && request.episode == null,
        done: false,
      );
    }

    // Send final state
    yield (
      request: request,
      result: lastResult,
      episodeUnknown: episodic && request.episode == null,
      done: true,
    );
  }

  Future<void> _auto(Stream<_SourceLookup> stream) async {
    final completer = Completer<_SourceLookup?>();
    _autoCompleter = completer;
    try {
      final preferred = await ref
          .read(resolverProvider)
          .preferredSource(widget.request.anime?.id);
      if (!mounted) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      _SourceLookup? latest;
      var streamDone = false;
      _subscription = stream.listen(
        (lookup) {
          latest = lookup;
          if (mounted) setState(() => _lookup = lookup);
          if (!lookup.episodeUnknown && !completer.isCompleted) {
            final offers = lookup.result.offers;
            final hasReliable = offers.any(
              PlaybackSession.canSelectAutomatically,
            );
            final hasPreferred =
                preferred != null &&
                offers.any((o) => o.offer.sourceId == preferred);
            if (hasReliable && (hasPreferred || preferred == null)) {
              completer.complete(lookup);
            }
          }
        },
        onDone: () {
          streamDone = true;
          if (!completer.isCompleted) {
            completer.complete(latest);
          }
        },
      );

      _SourceLookup? chosen;
      try {
        chosen = await completer.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        if (latest != null &&
            !latest!.episodeUnknown &&
            latest!.result.offers.any(PlaybackSession.canSelectAutomatically)) {
          chosen = latest;
        } else {
          chosen = await completer.future;
        }
      }
      if (!streamDone) {
        unawaited(_subscription?.cancel());
      }
      _subscription = null;

      if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (chosen != null &&
          !chosen.episodeUnknown &&
          chosen.result.offers.any(PlaybackSession.canSelectAutomatically)) {
        await _choose(chosen);
      }
    } on Exception {
      // The matching request displays its own error and retry action.
    } finally {
      if (!completer.isCompleted) completer.complete(null);
      if (identical(_autoCompleter, completer)) _autoCompleter = null;
      if (mounted) {
        setState(() => _autoPending = false);
      }
    }
  }

  @override
  void dispose() {
    if (_autoCompleter case final completer? when !completer.isCompleted) {
      completer.complete(null);
    }
    _subscription?.cancel();
    _address.dispose();
    super.dispose();
  }

  Future<void> _choose(_SourceLookup lookup, [RankedOffer? entry]) async {
    if (_busy) return;
    final request = lookup.request;
    final needsConfirmation =
        entry != null && (!entry.match.verified || lookup.episodeUnknown);
    if (needsConfirmation) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认剧集匹配'),
          content: Text(
            '${request.anime?.title ?? ''} ${request.episode?.label ?? ''}\n'
            '${entry.offer.label}\n\n'
            '${lookup.episodeUnknown ? '尚未确定当前剧集。本次选择仅用于本次播放。' : '${entry.match.reason}。确认后将记住此匹配。'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认匹配'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
    }
    final session =
        PlaybackSession(
            request,
            lookup.episodeUnknown ? const [] : lookup.result.offers,
            selected: entry?.offer,
          )
          ..resumeAt = widget.resumeAt
          ..previousDuration = widget.previousDuration;
    final first = session.next();
    if (first == null) return;
    await _action(() async {
      final resolver = ref.read(resolverProvider);
      if (entry != null && !entry.match.verified && !lookup.episodeUnknown) {
        await resolver.confirm(request, entry.offer);
      }
      return (candidate: await resolver.save(request, first), session: session);
    });
  }

  Future<void> _submit(MediaSearchRequest request, {required bool local}) =>
      _action(() async {
        final resolver = ref.read(resolverProvider);
        if (local) {
          await resolver.registry.enabledAdapter('local');
          final file = await const AndroidMediaAccess().pickVideo();
          if (file == null || !mounted) return null;
          final candidate = MediaCandidate.create(
            uri: file.uri,
            kind: MediaKind.document,
            sourceName: file.name,
            request: request,
          );
          await resolver.library.addMedia(candidate);
          final session = widget.resumeAt == null
              ? null
              : (PlaybackSession(request, const [])
                  ..resumeAt = widget.resumeAt
                  ..previousDuration = widget.previousDuration);
          return (candidate: candidate, session: session);
        }
        final uri = parsePlaybackUrl(_address.text);
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
          ..resumeAt = widget.resumeAt
          ..previousDuration = widget.previousDuration;
        session.next();
        return (
          candidate: await resolver.save(request, offer),
          session: session,
        );
      });

  Future<void> _action(Future<_PlaybackLaunch?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final media = await action();
      if (mounted &&
          media != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(media);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SourceIssue catch (error) {
      if (mounted) setState(() => _error = error.label);
    } on Exception {
      if (mounted) setState(() => _error = '无法读取或保存片源，请检查文件权限与网络。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autoPending || _lookup == null) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                _lookup == null
                    ? '正在确认剧集信息'
                    : '正在查找可播放片源',
              ),
              const SizedBox(height: SpacingTokens.sm),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return _choices(_lookup);
  }

  Widget _choices(_SourceLookup? lookup) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          SpacingTokens.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(widget.request.anime == null ? '打开视频' : '播放来源'),
            if ((lookup?.request.episode ?? widget.request.episode)
                case final episode?)
              Text(episode.label),
            const SizedBox(height: SpacingTokens.xs),
            if (lookup != null && !lookup.done)
              const Padding(
                padding: EdgeInsets.only(bottom: SpacingTokens.sm),
                child: LinearProgressIndicator(semanticsLabel: '正在查询片源'),
              ),
            if (lookup == null)
              StatusPanel(
                icon: Icons.error_outline_rounded,
                title: '无法查询片源',
                action: '重试',
                onAction: () => setState(_load),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lookup.episodeUnknown)
                    StatusPanel(
                      icon: Icons.info_outline_rounded,
                      title: '未能确定首集',
                      message: '可以手动指定片源，或重新查询剧集。',
                      action: '重新查询',
                      onAction: _busy ? null : () => setState(_load),
                    ),
                  if (lookup.result.offers.isEmpty)
                    StatusPanel(
                      icon: Icons.video_library_outlined,
                      title: '暂无可用视频资源',
                      message: '已启用的播放片源中没有匹配资源。',
                      action: '管理片源',
                      onAction: _busy
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              unawaited(router.push<void>('/sources'));
                            },
                    )
                  else ...[
                    if (!lookup.episodeUnknown &&
                        lookup.result.offers.any(
                          PlaybackSession.canSelectAutomatically,
                        ))
                      SoftButton(
                        label: '自动选择',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _busy ? null : () => _choose(lookup),
                      ),
                    ..._buildOfferList(context, lookup),
                  ],
                  for (final failure in lookup.result.diagnostics.entries)
                    Text(
                      '${failure.key} · ${failure.value.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            const SizedBox(height: SpacingTokens.md),
            SoftButton(
              label: '选择本地视频',
              icon: Icons.folder_open_rounded,
              onPressed: _busy
                  ? null
                  : () =>
                        _submit(lookup?.request ?? widget.request, local: true),
            ),
            const SizedBox(height: SpacingTokens.md),
            TextField(
              controller: _address,
              enabled: !_busy,
              obscureText: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) =>
                  _submit(lookup?.request ?? widget.request, local: false),
              decoration: InputDecoration(
                labelText: 'MP4 或 HLS 地址',
                helperText: '请输入你有权访问的视频地址。',
                errorText: _error,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            SoftButton(
              label: '添加并播放',
              icon: Icons.play_arrow_rounded,
              style: SoftStyle.accent,
              onPressed: _busy
                  ? null
                  : () => _submit(
                      lookup?.request ?? widget.request,
                      local: false,
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _buildOfferList(BuildContext context, _SourceLookup lookup) {
    final offers = lookup.result.offers;
    final fansubs = <String>{
      for (final o in offers) ?o.match.fansub,
    }.toList(growable: false);
    final resolutions = <String>{
      for (final o in offers) ?o.match.resolution,
    }.toList(growable: false);
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
    final type = Theme.of(context).textTheme;

    return [
      if (fansubs.length >= 2 || resolutions.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: SpacingTokens.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (fansubs.length >= 2)
                  for (final sub in fansubs)
                    Padding(
                      padding: const EdgeInsets.only(right: SpacingTokens.xs),
                      child: FilterChip(
                        label: Text(sub),
                        selected: activeFansub == sub,
                        onSelected: (selected) => setState(
                          () => _fansubFilter = selected ? sub : null,
                        ),
                      ),
                    ),
                if (resolutions.length >= 2)
                  for (final res in resolutions)
                    Padding(
                      padding: const EdgeInsets.only(right: SpacingTokens.xs),
                      child: FilterChip(
                        label: Text(res),
                        selected: activeRes == res,
                        onSelected: (selected) => setState(
                          () => _resolutionFilter = selected ? res : null,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      const SizedBox(height: SpacingTokens.xs),
      for (final entry in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
          child: Material(
            color: ColorTokens.surface.withValues(alpha: .72),
            borderRadius: RadiusTokens.card,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : () => _choose(lookup, entry),
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.match.verified
                          ? Icons.verified_outlined
                          : Icons.play_circle_outline_rounded,
                      color: entry.match.verified
                          ? ColorTokens.accent
                          : ColorTokens.muted,
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.offer.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: type.bodyMedium,
                          ),
                          const SizedBox(height: SpacingTokens.xxs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _TagPill(
                                '${entry.health.label} · ${entry.match.score}%',
                                accent: entry.match.verified,
                              ),
                              for (final tag in entry.match.tags) _TagPill(tag),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.xxs),
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
    ];
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill(this.text, {this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent
          ? ColorTokens.accent.withValues(alpha: .16)
          : ColorTokens.shadow,
      borderRadius: RadiusTokens.pill,
      border: Border.all(
        color: accent
            ? ColorTokens.accent.withValues(alpha: .5)
            : ColorTokens.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent ? ColorTokens.accent : ColorTokens.muted,
        ),
      ),
    ),
  );
}
