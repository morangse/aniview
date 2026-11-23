import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/media.dart';
import '../../media/playback_controller.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/playback_relay.dart';
import '../../media/sources/release_title_parser.dart';
import '../../media/sources/source_models.dart';
import '../anime/anime.dart';
import 'overlay_controls.dart';
import 'player_controls_bar.dart';
import 'player_resolve_screen.dart';
import 'skip_markers.dart';
import 'source_sheet.dart';

typedef MediaLinkState = ({String source, String key, String label});

class SessionWatchProgress implements WatchProgressRepository {
  const SessionWatchProgress(this.source, this.position, this.duration);
  final WatchProgressRepository source;
  final Duration position;
  final Duration? duration;

  @override
  Future<WatchProgress?> load(String id) async => WatchProgress(
    position: position,
    duration: duration ?? Duration.zero,
    completed: false,
    updatedAt: DateTime.now(),
  );

  @override
  Future<void> save(String id, WatchProgress value) => source.save(id, value);

  @override
  Stream<List<WatchEntry>> watchHistory() => source.watchHistory();
}

class PlayerSessionHelper {
  const PlayerSessionHelper._();

  static Future<MediaLinkState?> resolveLinkState(
    MediaResolver resolver,
    MediaCandidate candidate,
    PlaybackSession? session,
  ) async {
    final link = await resolver.store.linked(candidate.id);
    final current = session?.current;
    if (current != null) {
      return (key: current.key, source: current.sourceId, label: current.label);
    }
    if (link == null) return null;
    return (
      key: link.resourceKey,
      source: link.sourceId,
      label: candidate.sourceName,
    );
  }

  static Future<PlaybackRelay?> openRelayIfNeeded(
    StreamAccess access,
    MediaResolver resolver,
  ) =>
      access.restrictOrigin || access.headers.isNotEmpty || access.uri.hasQuery
          ? PlaybackRelay.open(access, resolver.registry.http)
          : Future.value(null);

  static Future<({MediaLinkState? link, Uri uri, PlaybackRelay? relay})>
  openSessionTarget(
    MediaResolver resolver,
    MediaCandidate candidate,
    PlaybackSession? session,
  ) async {
    final link = await resolveLinkState(resolver, candidate, session);
    final access = await resolver
        .access(candidate)
        .timeout(const Duration(seconds: 12));
    final relay = await openRelayIfNeeded(access, resolver);
    return (link: link, uri: relay?.uri ?? access.uri, relay: relay);
  }

  static Future<void> recordSuccess(
    MediaResolver resolver,
    MediaCandidate candidate,
    MediaLinkState link,
    int elapsedMs,
  ) async {
    try {
      await resolver.store.recordHealth(
        link.key,
        SourceState.available,
        startup: elapsedMs,
      );
      if (candidate.subjectId case final subjectId?) {
        await resolver.rememberWorkingSource(
          subjectId,
          link.source,
          label: link.label,
        );
      }
    } on Exception {
      // Metrics are best-effort throughout the playback lifecycle.
    }
  }

  static Future<MediaCandidate?> advanceFailover({
    required MediaResolver resolver,
    required PlaybackSession? session,
    required MediaLinkState? record,
    required String error,
    required SourceState sourceState,
    required PlaybackController? controller,
  }) async {
    if (record != null) {
      unawaited(
        resolver.store
            .recordHealth(record.key, sourceState, playbackFailure: true)
            .catchError((Object _) {}),
      );
      session?.failedLabels.add('${record.label} · $error');
    }
    final next = session?.next();
    if (next == null || session == null) return null;
    if (controller != null) {
      final pos = controller.positionListenable.value;
      final dur = controller.durationListenable.value;
      if (pos > Duration.zero && dur > Duration.zero) {
        session.resumeAt = pos;
        session.previousDuration = dur;
      }
    }
    return resolver.save(session.request, next);
  }

  static Future<MediaSearchRequest> resolveRequest({
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    PlaybackSession? session,
  }) async {
    final planned = session?.request;
    if (planned?.anime != null) return planned!;
    final id = candidate.subjectId;
    if (id == null) return const MediaSearchRequest();
    final anime = (await catalog.subject(id)).value;
    final episodeId = candidate.episodeId;
    if (episodeId == null) return MediaSearchRequest(anime: anime);
    final episodes = (await catalog.episodes(id)).value;
    final episode = episodes
        .where((entry) => entry.id == episodeId)
        .firstOrNull;
    return MediaSearchRequest(anime: anime, episode: episode);
  }

  static Future<
    ({Anime? anime, List<Episode> episodes, Episode? next, int? currentId})
  >
  resolveEpisodeContext({
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    PlaybackSession? session,
  }) async {
    final request = await resolveRequest(
      candidate: candidate,
      catalog: catalog,
      session: session,
    );
    final anime = request.anime;
    if (anime == null) {
      return (
        anime: null,
        episodes: const <Episode>[],
        next: null,
        currentId: request.episode?.id,
      );
    }
    final list = (await catalog.episodes(anime.id)).value;
    final index = list.indexWhere((ep) => ep.id == request.episode?.id);
    final next = index >= 0 && index + 1 < list.length ? list[index + 1] : null;
    return (
      anime: anime,
      episodes: list,
      next: next,
      currentId: request.episode?.id,
    );
  }

  static Future<({bool supportsPip, double? brightness, SkipMarkers markers})>
  loadStartupInfo(
    PlayerDeviceBridge device,
    MediaResolver resolver,
    MediaCandidate candidate,
  ) async {
    final supportsPip = await device.supportsPip();
    final brightness = await device.getWindowBrightness();
    var markers = const SkipMarkers();
    if (candidate.subjectId case final id?) {
      markers = await SkipMarkersStore(resolver.store).load(id);
    }
    return (
      supportsPip: supportsPip,
      brightness: brightness >= 0 ? brightness : null,
      markers: markers,
    );
  }

  static Future<({bool supportsPip, double? brightness, SkipMarkers markers})?>
  loadStartupInfoSafely(
    PlayerDeviceBridge device,
    MediaResolver resolver,
    MediaCandidate candidate,
  ) async {
    try {
      return await loadStartupInfo(device, resolver, candidate);
    } on Exception {
      return null;
    }
  }

  static Future<void> switchSourceFlow({
    required BuildContext context,
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    required PlaybackSession? session,
    required PlaybackController? controller,
    MediaSearchRequest? request,
    bool keepTime = true,
  }) async {
    try {
      final target =
          request ??
          await resolveRequest(
            candidate: candidate,
            catalog: catalog,
            session: session,
          );
      if (!context.mounted) return;
      if (controller != null) await controller.pause();
      if (!context.mounted) return;
      if (AdaptiveLayout.isApplePlatform) {
        context.replace(
          '/player/resolve',
          extra: PlayerResolveArgs(
            request: target,
            autoPlay: !keepTime,
            forceShowSources: keepTime,
            resumeAt: keepTime
                ? (controller?.positionListenable.value ?? session?.resumeAt)
                : null,
            previousDuration: keepTime
                ? (controller?.durationListenable.value ??
                      session?.previousDuration)
                : null,
          ),
        );
        return;
      }
      await showSources(
        context,
        request: target,
        replacePlayer: true,
        resumeAt: keepTime
            ? (controller?.positionListenable.value ?? session?.resumeAt)
            : null,
        previousDuration: keepTime
            ? (controller?.durationListenable.value ??
                  session?.previousDuration)
            : null,
      );
    } on Exception {
      if (context.mounted) inform(context, '无法读取剧集资料。请检查网络或从详情页切换。');
    }
  }

  static Future<void> pickEpisodeFlow({
    required BuildContext context,
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    required PlaybackSession? session,
    required Future<void> Function(MediaSearchRequest request) onSwitch,
  }) async {
    try {
      final info = await resolveEpisodeContext(
        candidate: candidate,
        catalog: catalog,
        session: session,
      );
      if (info.anime == null || !context.mounted) return;
      final selected = await showEpisodePickerSheet(
        context: context,
        episodes: info.episodes,
        currentEpisodeId: info.currentId,
        nextEpisode: info.next,
      );
      if (!context.mounted ||
          selected == null ||
          selected.id == info.currentId) {
        return;
      }
      await onSwitch(MediaSearchRequest(anime: info.anime, episode: selected));
    } on Exception {
      if (context.mounted) inform(context, '剧集列表暂不可用。');
    }
  }

  static Future<void> playNextFlow({
    required BuildContext context,
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    required PlaybackSession? session,
    required PlaybackController? controller,
    required bool seekEndOnMissing,
    required Future<void> Function(MediaSearchRequest request) onSwitch,
    required Future<void> Function(Future<void> Function() command) runCommand,
  }) async {
    try {
      final info = await resolveEpisodeContext(
        candidate: candidate,
        catalog: catalog,
        session: session,
      );
      if (!context.mounted) return;
      if (info.anime != null && info.next != null) {
        await onSwitch(
          MediaSearchRequest(anime: info.anime, episode: info.next),
        );
      } else if (seekEndOnMissing && controller != null) {
        final dur = controller.durationListenable.value;
        if (dur > Duration.zero) await runCommand(() => controller.seek(dur));
      } else {
        inform(context, '没有下一集了。');
      }
    } on Exception {
      if (context.mounted) inform(context, '无法读取下一集信息。');
    }
  }

  static Future<void> playPreviousFlow({
    required BuildContext context,
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    required PlaybackSession? session,
    required Future<void> Function(MediaSearchRequest request) onSwitch,
  }) async {
    try {
      final info = await resolveEpisodeContext(
        candidate: candidate,
        catalog: catalog,
        session: session,
      );
      if (!context.mounted) return;
      final index = info.episodes.indexWhere((ep) => ep.id == info.currentId);
      final prev = index > 0 ? info.episodes[index - 1] : null;
      if (info.anime != null && prev != null) {
        await onSwitch(MediaSearchRequest(anime: info.anime, episode: prev));
      } else {
        inform(context, '已经是第一集了。');
      }
    } on Exception {
      if (context.mounted) inform(context, '无法读取上一集信息。');
    }
  }

  static Future<void> autoNextCountdownFlow({
    required MediaCandidate candidate,
    required AnimeRepository catalog,
    required PlaybackSession? session,
    required AutoNextCountdown autoNext,
    required bool Function() canStart,
    required VoidCallback onTick,
    required void Function(Anime anime, Episode episode) onSwitch,
  }) async {
    try {
      final info = await resolveEpisodeContext(
        candidate: candidate,
        catalog: catalog,
        session: session,
      );
      if (info.anime == null || info.next == null || !canStart()) return;
      autoNext.start(
        nextEpisode: info.next!,
        onTick: onTick,
        onComplete: (ep) => onSwitch(info.anime!, ep),
      );
    } on Exception {
      // Auto-next lookup fails silently without disrupting playback UI.
    }
  }

  static void skipSecondsCommand(
    PlaybackController? controller,
    int seconds,
    Future<void> Function(Future<void> Function() command) runCommand,
    ValueChanged<String> flash,
  ) {
    if (controller == null) return;
    final duration = controller.durationListenable.value;
    if (!controller.value.ready || duration <= Duration.zero) return;
    final ms =
        (controller.positionListenable.value.inMilliseconds + seconds * 1000)
            .clamp(0, duration.inMilliseconds);
    unawaited(runCommand(() => controller.seek(Duration(milliseconds: ms))));
    flash(seconds > 0 ? '快进 ${seconds.abs()} 秒' : '快退 ${seconds.abs()} 秒');
  }

  static void skipIntroCommand(
    PlaybackController? controller,
    SkipMarkers markers,
    Future<void> Function(Future<void> Function() command) runCommand,
  ) {
    final introMs = markers.introEndMs;
    if (controller == null || introMs == null) return;
    unawaited(runCommand(() => controller.seek(Duration(milliseconds: introMs))));
  }

  static double? rateHoldCommand(
    PlaybackController? controller,
    bool start,
    double? priorRate,
    Future<void> Function(Future<void> Function() command) runCommand,
    ValueChanged<String> flash,
  ) {
    if (controller == null || !controller.value.ready) return priorRate;
    if (start) {
      if (!controller.value.playing) return priorRate;
      unawaited(runCommand(() => controller.setRate(2)));
      flash('2× 临时倍速');
      return controller.value.rate;
    }
    if (priorRate != null) {
      unawaited(runCommand(() => controller.setRate(priorRate)));
    }
    return null;
  }

  static void openDanmakuComposer(
    BuildContext context,
    WidgetRef ref,
    MediaCandidate media,
    PlaybackController? controller,
  ) {
    if (controller == null) return;
    unawaited(
      showDanmakuComposerDialog(
        context: context,
        ref: ref,
        media: media,
        controller: controller,
      ),
    );
  }

  static void pauseIfBackgrounded(
    AppLifecycleState state,
    PlaybackController? controller,
    bool inPip,
    Future<void> Function(Future<void> Function() command) runCommand,
  ) {
    if (controller != null &&
        !inPip &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      unawaited(runCommand(controller.pause));
    }
  }

  static Future<void> runGuardedCommand(
    BuildContext context,
    Future<void> Function() command,
  ) async {
    try {
      await command();
    } on Exception {
      if (context.mounted) inform(context, '播放器暂时无法完成此操作。');
    }
  }

  static Future<void> applyFullscreen({
    required BuildContext context,
    required PlayerDeviceBridge device,
    required bool enter,
    required VoidCallback onRevert,
  }) async {
    try {
      await device.setFullscreen(enter);
    } on Exception {
      if (context.mounted) {
        onRevert();
        inform(context, '此设备暂时无法切换全屏。');
      }
      await device.setFullscreen(false).catchError((Object _) {});
    }
  }
}

class PlayerHudController {
  PlayerHudController({
    required this.isMounted,
    required this.isPlaying,
    required this.notify,
  });

  final bool Function() isMounted;
  final bool Function() isPlaying;
  final VoidCallback notify;

  bool controls = true;
  bool locked = false;
  bool drawerOpen = false;
  int drawerTab = 0;
  String? gestureHint;
  Timer? _hintTimer;
  Timer? _controlsTimer;

  void _update(VoidCallback mutate) {
    mutate();
    if (isMounted()) notify();
  }

  void scheduleHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (isMounted() && controls && !drawerOpen && isPlaying()) {
        _update(() => controls = false);
      }
    });
  }

  void cancelHide() => _controlsTimer?.cancel();

  void ensureAutoHide() {
    if (controls && _controlsTimer?.isActive != true) scheduleHide();
  }

  void toggleControls(bool inPip) {
    if (locked || inPip) return;
    _update(() {
      if (drawerOpen) {
        drawerOpen = false;
        controls = true;
      } else {
        controls = !controls;
      }
    });
    if (controls) scheduleHide();
  }

  void toggleLock() {
    _update(() {
      drawerOpen = false;
      controls = !(locked = !locked);
    });
    if (controls) scheduleHide();
  }

  void openDrawer(int tab) {
    cancelHide();
    _update(() {
      drawerTab = tab;
      drawerOpen = true;
    });
  }

  void closeDrawer() => _update(() => drawerOpen = false);

  void applyPip(bool inPip) {
    if (inPip) {
      controls = false;
      drawerOpen = false;
    } else if (!locked) {
      controls = true;
      scheduleHide();
    }
  }

  void resetForFullscreen() {
    drawerOpen = false;
    controls = true;
  }

  void flash(String message) {
    _hintTimer?.cancel();
    _update(() => gestureHint = message);
    _hintTimer = Timer(const Duration(milliseconds: 670), () {
      if (isMounted()) _update(() => gestureHint = null);
    });
  }

  void dispose() {
    _hintTimer?.cancel();
    _controlsTimer?.cancel();
  }
}

class PlayerUnavailableView extends StatelessWidget {
  const PlayerUnavailableView({
    super.key,
    required this.loading,
    required this.onOpenSource,
  });

  final bool loading;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('播放器')),
    body: PageColumn(
      children: [
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          StatusPanel(
            icon: Icons.video_file_outlined,
            title: '片源不可用',
            message: '请重新选择文件或添加播放地址。',
            action: '打开视频',
            onAction: onOpenSource,
          ),
      ],
    ),
  );
}

class PlayerErrorPanel extends StatelessWidget {
  const PlayerErrorPanel({
    super.key,
    required this.message,
    required this.switching,
    required this.failedLabels,
    required this.onRetry,
    required this.onSwitchSource,
  });

  final String message;
  final bool switching;
  final List<String> failedLabels;
  final VoidCallback onRetry;
  final VoidCallback onSwitchSource;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: SpacingTokens.horizontal,
        child: Panel(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(switching ? '正在切换片源' : '播放失败'),
                  Text(message),
                  for (final previous in failedLabels.take(3))
                    Text(
                      previous,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: SpacingTokens.xs),
                  if (switching)
                    const LinearProgressIndicator()
                  else
                    Wrap(
                      spacing: SpacingTokens.xs,
                      children: [
                        SoftButton(label: '重试', onPressed: onRetry),
                        SoftButton(
                          label: '更换片源',
                          style: SoftStyle.outline,
                          onPressed: onSwitchSource,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showPlayerSettingsPanelSheet({
  required BuildContext context,
  required Widget Function(VoidCallback onClose) builder,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 580),
  sheetAnimationStyle: MotionTokens.sheetStyle(context),
  builder: (sheetCtx) => SafeArea(
    top: false,
    child: FractionallySizedBox(
      heightFactor: 0.72,
      child: builder(() => Navigator.of(sheetCtx).pop()),
    ),
  ),
);

Future<void> showPlayerSettingsSheet({
  required BuildContext context,
  required int initialTab,
  required MediaCandidate media,
  required PlaybackController controller,
  required MediaResolver resolver,
  required bool full,
  required bool supportsPip,
  required SkipMarkers skipMarkers,
  required ValueChanged<SkipMarkers> onMarkersChanged,
  required Future<void> Function(Future<void> Function() command) runCommand,
  required VoidCallback onEnterPip,
  required VoidCallback onToggleLock,
  required VoidCallback onSwitchSource,
  required void Function(Anime? anime, Episode episode) onSelectEpisode,
}) => showPlayerSettingsPanelSheet(
  context: context,
  builder: (onClose) => PlayerSettingsPanel(
    initialTab: initialTab,
    media: media,
    controller: controller,
    resolver: resolver,
    full: full,
    supportsPip: supportsPip,
    skipMarkers: skipMarkers,
    onMarkersChanged: onMarkersChanged,
    runCommand: runCommand,
    onEnterPip: onEnterPip,
    onToggleLock: onToggleLock,
    onSwitchSource: onSwitchSource,
    onSelectEpisode: onSelectEpisode,
    onClose: onClose,
  ),
);

class PlayerSettingsPanel extends ConsumerStatefulWidget {
  const PlayerSettingsPanel({
    super.key,
    required this.initialTab,
    required this.media,
    required this.controller,
    required this.resolver,
    required this.full,
    required this.supportsPip,
    required this.skipMarkers,
    required this.onMarkersChanged,
    required this.runCommand,
    required this.onEnterPip,
    required this.onToggleLock,
    required this.onSwitchSource,
    required this.onSelectEpisode,
    required this.onClose,
  });

  final int initialTab;
  final MediaCandidate media;
  final PlaybackController controller;
  final MediaResolver resolver;
  final bool full;
  final bool supportsPip;
  final SkipMarkers skipMarkers;
  final ValueChanged<SkipMarkers> onMarkersChanged;
  final Future<void> Function(Future<void> Function() command) runCommand;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleLock;
  final VoidCallback onSwitchSource;
  final void Function(Anime? anime, Episode episode) onSelectEpisode;
  final VoidCallback onClose;

  @override
  ConsumerState<PlayerSettingsPanel> createState() =>
      _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends ConsumerState<PlayerSettingsPanel> {
  late SkipMarkers _markers = widget.skipMarkers;
  bool _showInlineSources = false;

  void _saveMarkers(SkipMarkers next) {
    setState(() => _markers = next);
    widget.onMarkersChanged(next);
    if (widget.media.subjectId case final subjectId?) {
      unawaited(
        SkipMarkersStore(
          widget.resolver.store,
        ).save(subjectId, next).catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: widget.initialTab.clamp(0, 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
          child: Row(
            children: [
              const Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: '播放'),
                    Tab(text: '弹幕'),
                    Tab(text: '字幕音轨'),
                    Tab(text: '选集片源'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _buildPlaybackTab(context),
              SingleChildScrollView(
                padding: const EdgeInsets.all(SpacingTokens.md),
                child: DanmakuControlPane(
                  media: widget.media,
                  controller: widget.controller,
                  onCloseForComposer: widget.onClose,
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(SpacingTokens.md),
                child: SubtitleAndAudioPane(
                  media: widget.media,
                  controller: widget.controller,
                  runCommand: widget.runCommand,
                ),
              ),
              _buildEpisodeSourceTab(context),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildPlaybackTab(BuildContext context) {
    final autoNext = ref.watch(autoNextProvider).value ?? true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: ValueListenableBuilder<PlaybackViewState>(
        valueListenable: widget.controller,
        builder: (_, state, _) {
          final pos = widget.controller.positionListenable.value;
          final dur = widget.controller.durationListenable.value;
          final introLabel = _markers.introEndMs == null
              ? '未设置'
              : formatPlaybackTime(
                  Duration(milliseconds: _markers.introEndMs!),
                );
          final outroLabel = _markers.outroDurationMs == null
              ? '未设置'
              : '${(_markers.outroDurationMs! / 1000).round()} 秒';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading('倍速'),
              const SizedBox(height: SpacingTokens.xs),
              Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: [
                  for (final rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    SoftButton(
                      label: '${formatPlaybackNumber(rate)}×',
                      selected: state.rate == rate,
                      onPressed: () =>
                          widget.runCommand(() => widget.controller.setRate(rate)),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.md),
              Text('音量  ${state.volume.round()}%（最高 150% 增益）'),
              Slider(
                value: state.volume.clamp(0, 150),
                max: 150,
                onChanged: (value) =>
                    widget.runCommand(() => widget.controller.setVolume(value)),
              ),
              if (widget.media.subjectId != null) ...[
                const SizedBox(height: SpacingTokens.sm),
                const SectionHeading('跳过片头片尾'),
                const SizedBox(height: SpacingTokens.xs),
                Text('片头结束：$introLabel   ·   片尾时长：$outroLabel'),
                const SizedBox(height: SpacingTokens.xs),
                Wrap(
                  spacing: SpacingTokens.xs,
                  runSpacing: SpacingTokens.xs,
                  children: [
                    SoftButton(
                      label: '当前设为片头结束',
                      onPressed: pos <= Duration.zero
                          ? null
                          : () => _saveMarkers(
                              _markers.copyWith(introEndMs: pos.inMilliseconds),
                            ),
                    ),
                    SoftButton(
                      label: '剩余设为片尾',
                      onPressed: dur <= pos || dur <= Duration.zero
                          ? null
                          : () {
                              final rem = (dur - pos).inMilliseconds;
                              if (rem > 1000) {
                                _saveMarkers(
                                  _markers.copyWith(outroDurationMs: rem),
                                );
                              }
                            },
                    ),
                    if (_markers.introEndMs != null)
                      SoftButton(
                        label: '清除片头',
                        style: SoftStyle.clear,
                        onPressed: () =>
                            _saveMarkers(_markers.copyWith(introEndMs: null)),
                      ),
                    if (_markers.outroDurationMs != null)
                      SoftButton(
                        label: '清除片尾',
                        style: SoftStyle.clear,
                        onPressed: () => _saveMarkers(
                          _markers.copyWith(outroDurationMs: null),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: SpacingTokens.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('播完自动连播下一集'),
                value: autoNext,
                onChanged: (value) =>
                    unawaited(ref.read(libraryProvider).setAutoNext(value)),
              ),
              if (widget.supportsPip || widget.full) ...[
                const SizedBox(height: SpacingTokens.xs),
                Wrap(
                  spacing: SpacingTokens.xs,
                  children: [
                    if (widget.supportsPip)
                      SoftButton(
                        label: '画中画',
                        icon: Icons.picture_in_picture_alt_rounded,
                        style: SoftStyle.outline,
                        onPressed: () {
                          widget.onClose();
                          widget.onEnterPip();
                        },
                      ),
                    if (widget.full)
                      SoftButton(
                        label: '锁屏',
                        icon: Icons.lock_outline_rounded,
                        style: SoftStyle.outline,
                        onPressed: () {
                          widget.onClose();
                          widget.onToggleLock();
                        },
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeSourceTab(BuildContext context) {
    final subjectId = widget.media.subjectId;
    final parsed = ReleaseTitleParser.parse(widget.media.sourceName);
    final episodesAsync =
        subjectId == null ? null : ref.watch(episodesProvider(subjectId));
    final anime =
        subjectId == null ? null : ref.watch(subjectProvider(subjectId)).value?.value;
    final episodes = episodesAsync?.value?.value ?? const <Episode>[];
    final currentEp = episodes
        .where((ep) => ep.id == widget.media.episodeId)
        .firstOrNull;
    final isApple = AdaptiveLayout.isApplePlatform;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading('当前片源'),
          const SizedBox(height: SpacingTokens.xs),
          Panel(
            child: ListTile(
              title: Text(
                widget.media.sourceName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: parsed.displayTags.isEmpty
                  ? null
                  : Text(parsed.displayTags.join(' · ')),
              trailing: Icon(
                isApple && _showInlineSources
                    ? Icons.expand_less_rounded
                    : Icons.swap_horiz_rounded,
              ),
              onTap: () {
                if (isApple) {
                  setState(() => _showInlineSources = !_showInlineSources);
                } else {
                  widget.onClose();
                  widget.onSwitchSource();
                }
              },
            ),
          ),
          if (isApple && _showInlineSources) ...[
            const SizedBox(height: SpacingTokens.sm),
            InPlayerSourcePanel(
              request: MediaSearchRequest(anime: anime, episode: currentEp),
              resumeAt: widget.controller.positionListenable.value,
              previousDuration: widget.controller.durationListenable.value,
              onLaunch: (launch) async {
                await widget.controller.pause();
                widget.onClose();
                if (context.mounted) {
                  context.replace(
                    '/player/${launch.candidate.id}',
                    extra: launch.session,
                  );
                }
              },
            ),
          ],
          if (episodes.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.md),
            const SectionHeading('选集'),
            const SizedBox(height: SpacingTokens.xs),
            Wrap(
              spacing: SpacingTokens.xs,
              runSpacing: SpacingTokens.xs,
              children: [
                for (final ep in episodes)
                  SoftButton(
                    label: ep.label,
                    selected: ep.id == widget.media.episodeId,
                    onPressed: () {
                      if (ep.id == widget.media.episodeId) return;
                      widget.onClose();
                      widget.onSelectEpisode(anime, ep);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<Episode?> showEpisodePickerSheet({
  required BuildContext context,
  required List<Episode> episodes,
  required int? currentEpisodeId,
  required Episode? nextEpisode,
}) => showModalBottomSheet<Episode>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  sheetAnimationStyle: MotionTokens.sheetStyle(context),
  builder: (context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .65,
      child: Column(
        children: [
          Padding(
            padding: SpacingTokens.horizontal,
            child: SectionHeading(
              '选择剧集',
              action: nextEpisode == null ? null : '下一集',
              onAction: nextEpisode == null
                  ? null
                  : () => Navigator.of(context).pop(nextEpisode),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (_, i) {
                final episode = episodes[i];
                return ListTile(
                  title: Text(episode.label),
                  subtitle: Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: episode.id == currentEpisodeId,
                  onTap: () => Navigator.of(context).pop(episode),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
);
