import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../media/android_media_access.dart';
import '../../media/media.dart';
import '../../media/media_kit_playback.dart';
import '../../media/playback_controller.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/source_models.dart';
import '../anime/anime.dart';
import 'overlay_controls.dart';
import 'player_controls_bar.dart';
import 'player_details_area.dart';
import 'player_panels.dart';
import 'player_session_controller.dart';
import 'skip_markers.dart';
import 'source_sheet.dart';

typedef PlaybackFactory = PlaybackController Function(
  MediaCandidate,
  WatchProgressRepository,
);

final playbackFactoryProvider = Provider<PlaybackFactory>(
  (_) => MediaKitPlayback.new,
);

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key, required this.mediaId, this.session});
  final String mediaId;
  final PlaybackSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(mediaProvider(mediaId));
    final autoplay = ref.watch(autoplayProvider);
    final candidate = media.value;
    if (candidate != null && !autoplay.isLoading) {
      return _Player(
        key: ValueKey(mediaId),
        candidate: candidate,
        autoplay: autoplay.value ?? true,
        session: session,
      );
    }
    return PlayerUnavailableView(
      loading: media.isLoading || autoplay.isLoading,
      onOpenSource: () => showSources(context),
    );
  }
}

class _Player extends ConsumerStatefulWidget {
  const _Player({
    super.key,
    required this.candidate,
    required this.autoplay,
    this.session,
  });
  final MediaCandidate candidate;
  final bool autoplay;
  final PlaybackSession? session;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> with WidgetsBindingObserver {
  bool _full = false;
  bool _changingFullscreen = false;
  bool _inPip = false;
  bool _supportsPip = false;
  double? _holdRate;
  double? _brightness;
  bool _brightnessModified = false;
  SkipMarkers _skipMarkers = const SkipMarkers();
  bool _autoNextDismissed = false;
  bool _resolvingNext = false;
  final _autoNext = AutoNextCountdown();
  late final _hud = PlayerHudController(
    isMounted: () => mounted,
    isPlaying: () => _playback.controller?.value.playing == true,
    notify: () => setState(() {}),
  );
  late final PlayerDeviceBridge _device = ref.read(playerDeviceBridgeProvider);
  late final PlayerSessionController _playback;
  ValueListenable<bool>? _pipListenable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pipListenable = _device.pipModeListenable;
    _inPip = _pipListenable?.value ?? false;
    _pipListenable?.addListener(_onPipChanged);
    _playback = PlayerSessionController(
      candidate: widget.candidate,
      progress: ref.read(libraryProvider),
      factory: ref.read(playbackFactoryProvider),
      resolver: ref.read(resolverProvider),
      session: widget.session,
      onPlayingActive: _hud.ensureAutoHide,
      onCompletedChanged: (completed) {
        if (completed) {
          if ((ref.read(autoNextProvider).value ?? true) &&
              !_autoNextDismissed) {
            unawaited(_prepareAutoNext());
          }
        } else {
          _autoNextDismissed = false;
          if (_autoNext.cancel() && mounted) setState(() {});
        }
      },
      onFailoverNavigate: (nextId) {
        if (mounted) context.replace('/player/$nextId', extra: widget.session);
      },
    )..addListener(_onPlaybackChanged);
    unawaited(_initDeviceAndMarkers());
    unawaited(_playback.open(autoplay: widget.autoplay));
    _hud.scheduleHide();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initDeviceAndMarkers() async {
    final info = await PlayerSessionHelper.loadStartupInfoSafely(
      _device,
      ref.read(resolverProvider),
      widget.candidate,
    );
    if (!mounted || info == null) return;
    setState(() {
      _supportsPip = info.supportsPip;
      if (!_brightnessModified) _brightness = info.brightness;
      _skipMarkers = info.markers;
    });
  }

  void _onPipChanged() {
    final pip = _pipListenable?.value ?? false;
    if (!mounted || pip == _inPip) return;
    setState(() {
      _inPip = pip;
      _hud.applyPip(pip);
    });
  }

  void _openEpisode(Anime? anime, Episode ep) => unawaited(
    _switch(
      request: MediaSearchRequest(anime: anime, episode: ep),
      keepTime: false,
    ),
  );

  Future<void> _prepareAutoNext() async {
    if (_resolvingNext) return;
    _resolvingNext = true;
    await PlayerSessionHelper.autoNextCountdownFlow(
      candidate: widget.candidate,
      catalog: ref.read(animeRepositoryProvider),
      session: widget.session,
      autoNext: _autoNext,
      canStart: () =>
          mounted &&
          !_autoNextDismissed &&
          _playback.controller?.value.completed == true,
      onTick: () {
        if (mounted) setState(() {});
      },
      onSwitch: _openEpisode,
    );
    _resolvingNext = false;
  }

  Future<void> _switch({MediaSearchRequest? request, bool keepTime = true}) async {
    if (_autoNext.cancel() && mounted) setState(() {});
    await PlayerSessionHelper.switchSourceFlow(
      context: context,
      candidate: widget.candidate,
      catalog: ref.read(animeRepositoryProvider),
      session: widget.session,
      controller: _playback.controller,
      request: request,
      keepTime: keepTime,
    );
  }

  Future<void> _episodes() => PlayerSessionHelper.pickEpisodeFlow(
    context: context,
    candidate: widget.candidate,
    catalog: ref.read(animeRepositoryProvider),
    session: widget.session,
    onSwitch: (req) => _switch(request: req, keepTime: false),
  );

  Future<void> _playNext({bool seekEndOnMissing = false}) =>
      PlayerSessionHelper.playNextFlow(
        context: context,
        candidate: widget.candidate,
        catalog: ref.read(animeRepositoryProvider),
        session: widget.session,
        controller: _playback.controller,
        seekEndOnMissing: seekEndOnMissing,
        onSwitch: (req) => _switch(request: req, keepTime: false),
        runCommand: _run,
      );

  Future<void> _toggleDanmakuQuick() async {
    final result = await ref
        .read(overlayStoreProvider)
        .toggleDanmakuQuick(widget.candidate);
    if (!mounted) return;
    if (!result.hasTrack) {
      _openSettings(1);
      _hud.flash('请先载入或搜索弹幕');
      return;
    }
    ref.invalidate(overlayProvider(widget.candidate));
    _hud.flash(result.enabled ? '弹幕已开启' : '弹幕已关闭');
  }

  Widget _buildSettingsPanel(
    int tab,
    PlaybackController controller, {
    Key? key,
    required VoidCallback onClose,
  }) => PlayerSettingsPanel(
    key: key,
    initialTab: tab,
    media: widget.candidate,
    controller: controller,
    resolver: ref.read(resolverProvider),
    full: _full,
    supportsPip: _supportsPip,
    skipMarkers: _skipMarkers,
    onMarkersChanged: (m) => setState(() => _skipMarkers = m),
    runCommand: _run,
    onEnterPip: _enterPip,
    onToggleLock: _hud.toggleLock,
    onSwitchSource: () => unawaited(_switch()),
    onSelectEpisode: _openEpisode,
    onClose: onClose,
  );

  void _openSettings(int tab) {
    final controller = _playback.controller;
    if (controller == null) return;
    if (_full) {
      _hud.openDrawer(tab);
      return;
    }
    _hud.cancelHide();
    unawaited(
      showPlayerSettingsPanelSheet(
        context: context,
        builder: (onClose) =>
            _buildSettingsPanel(tab, controller, onClose: onClose),
      ).whenComplete(_hud.scheduleHide),
    );
  }

  void _enterPip() {
    if (!_supportsPip || !mounted) return;
    final ratio = _playback.controller?.value.aspectRatio ?? (16 / 9);
    unawaited(_device.enterPip(width: (ratio * 100).round(), height: 100));
  }

  Future<void> _toggleFullscreen() async {
    if (_changingFullscreen || !mounted) return;
    _changingFullscreen = true;
    final enter = !_full;
    setState(() {
      _full = enter;
      _hud.resetForFullscreen();
    });
    await PlayerSessionHelper.applyFullscreen(
      context: context,
      device: _device,
      enter: enter,
      onRevert: () => setState(() => _full = false),
    );
    _changingFullscreen = false;
  }

  Future<void> _run(Future<void> Function() command) =>
      PlayerSessionHelper.runGuardedCommand(context, command);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      PlayerSessionHelper.pauseIfBackgrounded(
        state,
        _playback.controller,
        _inPip || (_pipListenable?.value ?? false),
        _run,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipListenable?.removeListener(_onPipChanged);
    _playback.removeListener(_onPlaybackChanged);
    _playback.dispose();
    _hud.dispose();
    _autoNext.dispose();
    if (_full || _changingFullscreen) {
      unawaited(_device.setFullscreen(false).catchError((Object _) {}));
    }
    if (_brightnessModified) unawaited(_device.setWindowBrightness(-1.0));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoNextProvider);
    final controller = _playback.controller;
    final danmakuEnabled =
        ref.watch(overlayProvider(widget.candidate)).value?.settings.danmakuEnabled ??
        false;
    return PlayerScreenScaffold(
      full: _full,
      fullScreen: _full || _inPip,
      onExitFullscreen: () => unawaited(_toggleFullscreen()),
      viewport: PlayerViewport(
        candidate: widget.candidate,
        controller: controller,
        surface: _playback.surface,
        full: _full,
        controls: _hud.controls,
        locked: _hud.locked,
        inPip: _inPip,
        supportsPip: _supportsPip,
        danmakuEnabled: danmakuEnabled,
        drawerOpen: _hud.drawerOpen,
        switching: _playback.switching,
        failedLabels: widget.session?.failedLabels ?? const <String>[],
        skipMarkers: _skipMarkers,
        backendError: _playback.backendError,
        brightness: _brightness,
        gestureHint: _hud.gestureHint,
        autoNextEpisode: _autoNext.episode,
        autoNextSeconds: _autoNext.seconds,
        drawerBuilder: controller == null
            ? null
            : (_) => _buildSettingsPanel(
                _hud.drawerTab,
                controller,
                key: ValueKey('drawer-${_hud.drawerTab}'),
                onClose: _hud.closeDrawer,
              ),
        onBack: () => _full ? _toggleFullscreen() : context.pop(),
        onEnterPip: _enterPip,
        onOpenSettings: () => _openSettings(0),
        onCloseDrawer: _hud.closeDrawer,
        onRetry: () => unawaited(_playback.retry(autoplay: widget.autoplay)),
        onSwitchSource: _switch,
        onToggleControls: () => _hud.toggleControls(_inPip),
        onToggleLock: _hud.toggleLock,
        onSkipSeconds: (sec) => PlayerSessionHelper.skipSecondsCommand(
          controller,
          sec,
          _run,
          _hud.flash,
        ),
        onRateHold: (start) => _holdRate = PlayerSessionHelper.rateHoldCommand(
          controller,
          start,
          _holdRate,
          _run,
          _hud.flash,
        ),
        onBrightnessChanged: (v) {
          _brightnessModified = true;
          setState(() => _brightness = v);
          unawaited(_device.setWindowBrightness(v));
        },
        onVolumeChanged: (v) => controller == null ? null : unawaited(_run(() => controller.setVolume(v))),
        onSeek: (pos) => controller == null ? Future.value() : _run(() => controller.seek(pos)),
        onTogglePlayback: () => controller == null ? null : unawaited(_run(controller.toggle)),
        onToggleDanmaku: () => unawaited(_toggleDanmakuQuick()),
        onOpenComposer: () => PlayerSessionHelper.openDanmakuComposer(
          context,
          ref,
          widget.candidate,
          controller,
        ),
        onKeepControlsVisible: _hud.cancelHide,
        onScheduleHideControls: _hud.scheduleHide,
        onToggleFullscreen: _toggleFullscreen,
        onPlayNext: () => unawaited(_playNext()),
        onPlayNextNow: () {
          if (_autoNext.cancel()) setState(() {});
          unawaited(_playNext());
        },
        onCancelAutoNext: () {
          _autoNextDismissed = true;
          if (_autoNext.cancel()) setState(() {});
        },
        onSkipIntro: () =>
            PlayerSessionHelper.skipIntroCommand(controller, _skipMarkers, _run),
        onSkipOutro: () => unawaited(_playNext(seekEndOnMissing: true)),
        onOpenEpisodes: () => _full ? _openSettings(3) : _episodes(),
        onOpenSpeed: () => _openSettings(0),
        onOpenSubtitles: () => _openSettings(2),
      ),
      details: PlayerDetailsArea(
        candidate: widget.candidate,
        onSwitchSource: _switch,
        onOpenEpisodes: _episodes,
        onOpenDanmaku: () => _openSettings(1),
        onOpenSubtitles: () => _openSettings(2),
        onSelectEpisode: _openEpisode,
      ),
    );
  }
}
