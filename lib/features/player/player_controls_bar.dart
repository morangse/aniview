import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../../media/playback_controller.dart';
import '../anime/anime.dart';
import 'ios_player_controls.dart';
import 'overlay_controls.dart';
import 'player_gesture_layer.dart';
import 'player_panels.dart';
import 'skip_markers.dart';

String formatPlaybackTime(Duration duration) {
  String pad(int value) => value.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = pad(duration.inMinutes.remainder(60));
  final seconds = pad(duration.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String formatPlaybackNumber(double value) =>
    value % 1 == 0 ? '${value.toInt()}' : '$value';

class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.candidate,
    required this.onBack,
    this.full = false,
    this.danmakuEnabled = false,
    this.supportsPip = false,
    this.onEnterPip,
    this.onToggleDanmaku,
    this.onOpenComposer,
    this.onOpenSettings,
  });

  final MediaCandidate candidate;
  final VoidCallback onBack;
  final bool full;
  final bool danmakuEnabled;
  final bool supportsPip;
  final VoidCallback? onEnterPip;
  final VoidCallback? onToggleDanmaku;
  final VoidCallback? onOpenComposer;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (AdaptiveLayout.isApplePlatform && full) {
      return IosFullscreenHeader(
        candidate: candidate,
        danmakuEnabled: danmakuEnabled,
        supportsPip: supportsPip,
        onBack: onBack,
        onEnterPip: onEnterPip,
        onToggleDanmaku: onToggleDanmaku,
        onOpenComposer: onOpenComposer,
        onOpenSettings: onOpenSettings,
      );
    }
    return DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [ColorTokens.shadow, Colors.transparent],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.xs,
          SpacingTokens.xs,
          SpacingTokens.sm,
          SpacingTokens.sm,
        ),
        child: Row(
          children: [
            IconCapsuleButton(
              icon: Icons.arrow_back_rounded,
              label: '返回',
              style: SoftStyle.clear,
              onPressed: onBack,
            ),
            const SizedBox(width: SpacingTokens.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (candidate.episodeLabel case final label?)
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if ((supportsPip && onEnterPip != null) || onOpenSettings != null)
              LiquidGlassSurface(
                radius: RadiusTokens.pill,
                blur: 14,
                tint: ColorTokens.glassTint.withValues(alpha: 0.72),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (supportsPip && onEnterPip != null)
                      IconButton(
                        key: const ValueKey('pip-button'),
                        icon: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '画中画',
                        onPressed: onEnterPip,
                      ),
                    if (onOpenSettings != null)
                      IconButton(
                        key: const ValueKey('player-settings-button'),
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '设置',
                        onPressed: onOpenSettings,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }
}

class PlayerControlsFooter extends StatefulWidget {
  const PlayerControlsFooter({
    super.key,
    required this.controller,
    required this.state,
    required this.full,
    required this.danmakuEnabled,
    required this.skipMarkers,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onKeepControlsVisible,
    required this.onScheduleHideControls,
    required this.onToggleFullscreen,
    required this.onToggleDanmaku,
    required this.onOpenComposer,
    required this.onPlayNext,
    required this.onOpenEpisodes,
    required this.onOpenSpeed,
    required this.onOpenSubtitles,
    this.candidate,
    this.onToggleLock,
    this.onSkipSeconds,
    this.onPlayPrevious,
    this.onSwitchSource,
    this.onOpenSettings,
  });

  final PlaybackController controller;
  final PlaybackViewState state;
  final bool full;
  final bool danmakuEnabled;
  final SkipMarkers skipMarkers;
  final VoidCallback onTogglePlayback;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onKeepControlsVisible;
  final VoidCallback onScheduleHideControls;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onOpenComposer;
  final VoidCallback onPlayNext;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenSubtitles;
  final MediaCandidate? candidate;
  final VoidCallback? onToggleLock;
  final void Function(int seconds)? onSkipSeconds;
  final VoidCallback? onPlayPrevious;
  final VoidCallback? onSwitchSource;
  final VoidCallback? onOpenSettings;

  @override
  State<PlayerControlsFooter> createState() => _PlayerControlsFooterState();
}

class _PlayerControlsFooterState extends State<PlayerControlsFooter> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final playerAction = state.completed
        ? '重播'
        : state.playing
        ? '暂停'
        : '播放';
    final type = Theme.of(context).textTheme;

    final playPauseButton = IconButton(
      key: const ValueKey('toggle-playback'),
      icon: Icon(
        state.completed
            ? Icons.replay_rounded
            : state.playing
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        color: Colors.white,
      ),
      tooltip: playerAction,
      onPressed: widget.onTogglePlayback,
    );

    final danmakuButton = IconButton(
      key: const ValueKey('danmaku-quick-toggle'),
      icon: Icon(
        widget.danmakuEnabled
            ? Icons.subtitles_rounded
            : Icons.subtitles_off_outlined,
        color: widget.danmakuEnabled ? ColorTokens.accent : Colors.white70,
      ),
      tooltip: widget.danmakuEnabled ? '关闭弹幕' : '开启弹幕',
      onPressed: widget.onToggleDanmaku,
    );

    final fullScreenBtn = IconButton(
      icon: Icon(
        widget.full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
        color: Colors.white,
      ),
      tooltip: widget.full ? '退出全屏' : '全屏',
      onPressed: widget.onToggleFullscreen,
    );

    final timeline = ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller.positionListenable,
        widget.controller.durationListenable,
      ]),
      builder: (context, _) {
        final duration = widget.controller.durationListenable.value;
        final position = widget.controller.positionListenable.value;
        final maximum = duration.inMilliseconds.toDouble().clamp(
          0.0,
          double.infinity,
        );
        final preview = (_dragMs ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          maximum,
        );
        final slider = Slider(
          key: const ValueKey('seek-bar'),
          value: preview,
          max: maximum > 0 ? maximum : 1.0,
          onChanged: maximum > 0
              ? (value) {
                  widget.onKeepControlsVisible();
                  setState(() => _dragMs = value);
                }
              : null,
          onChangeEnd: maximum > 0
              ? (value) async {
                  await widget.onSeek(Duration(milliseconds: value.round()));
                  if (mounted) setState(() => _dragMs = null);
                  widget.onScheduleHideControls();
                }
              : null,
        );

        final bar = widget.skipMarkers.isEmpty || maximum <= 0
            ? slider
            : Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: CustomPaint(
                          painter: _SkipRangePainter(
                            durationMs: maximum,
                            markers: widget.skipMarkers,
                          ),
                        ),
                      ),
                    ),
                  ),
                  slider,
                ],
              );

        return Row(
          children: [
            Text(
              formatPlaybackTime(Duration(milliseconds: preview.round())),
              key: const ValueKey('playback-position'),
              style: type.labelSmall?.copyWith(color: Colors.white),
            ),
            if (!widget.full) ...[
              Text(' / ', style: type.labelSmall?.copyWith(color: Colors.white54)),
              Text(
                formatPlaybackTime(duration),
                style: type.labelSmall?.copyWith(color: Colors.white54),
              ),
            ],
            const SizedBox(width: SpacingTokens.xs),
            Expanded(child: bar),
            if (widget.full) ...[
              const SizedBox(width: SpacingTokens.xs),
              Text(
                formatPlaybackTime(duration),
                style: type.labelSmall?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        );
      },
    );

    if (!widget.full) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.xs,
          0,
          SpacingTokens.xs,
          SpacingTokens.xs,
        ),
        child: LiquidGlassSurface(
          radius: RadiusTokens.pill,
          blur: 14,
          tint: ColorTokens.glassTint.withValues(alpha: 0.72),
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs),
          child: Row(
            children: [
              playPauseButton,
              Expanded(child: timeline),
              danmakuButton,
              fullScreenBtn,
            ],
          ),
        ),
      );
    }

    if (AdaptiveLayout.isApplePlatform && widget.full) {
      return IosFullscreenFooter(
        candidate: widget.candidate,
        state: state,
        timeline: timeline,
        danmakuEnabled: widget.danmakuEnabled,
        onTogglePlayback: widget.onTogglePlayback,
        onToggleFullscreen: widget.onToggleFullscreen,
        onToggleDanmaku: widget.onToggleDanmaku,
        onOpenEpisodes: widget.onOpenEpisodes,
        onOpenSpeed: widget.onOpenSpeed,
        onOpenSubtitles: widget.onOpenSubtitles,
        onToggleLock: widget.onToggleLock,
        onSkipSeconds: widget.onSkipSeconds,
        onPlayPrevious: widget.onPlayPrevious,
        onPlayNext: widget.onPlayNext,
        onSwitchSource: widget.onSwitchSource,
        onOpenSettings: widget.onOpenSettings,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.md,
          0,
          SpacingTokens.md,
          SpacingTokens.xs,
        ),
        child: LiquidGlassSurface(
          radius: RadiusTokens.panel,
          blur: 20,
          elevated: true,
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.sm,
            SpacingTokens.xxs,
            SpacingTokens.sm,
            SpacingTokens.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.storageError)
                const Text(
                  '本次观看进度暂时无法保存。',
                  style: TextStyle(color: Colors.white),
                ),
              timeline,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      playPauseButton,
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '下一集',
                        onPressed: widget.onPlayNext,
                      ),
                      danmakuButton,
                      IconButton(
                        key: const ValueKey('danmaku-send-button'),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '发弹幕',
                        onPressed: widget.onOpenComposer,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CompactBarAction('选集', onPressed: widget.onOpenEpisodes),
                      _CompactBarAction(
                        '${formatPlaybackNumber(state.rate)}×',
                        onPressed: widget.onOpenSpeed,
                      ),
                      _CompactBarAction(
                        '字幕音轨',
                        onPressed: widget.onOpenSubtitles,
                      ),
                      fullScreenBtn,
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactBarAction extends StatelessWidget {
  const _CompactBarAction(this.label, {required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

class _SkipRangePainter extends CustomPainter {
  const _SkipRangePainter({required this.durationMs, required this.markers});
  final double durationMs;
  final SkipMarkers markers;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0) return;
    final y = size.height / 2;
    final paint = Paint()
      ..color = ColorTokens.accent.withValues(alpha: 0.48)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (markers.introEndMs case final introEnd? when introEnd > 0) {
      final frac = (introEnd / durationMs).clamp(0.0, 1.0);
      canvas.drawLine(Offset(0, y), Offset(size.width * frac, y), paint);
    }
    if (markers.outroDurationMs case final outro? when outro > 0) {
      final startFrac = ((durationMs - outro) / durationMs).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(size.width * startFrac, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SkipRangePainter oldDelegate) =>
      oldDelegate.durationMs != durationMs || oldDelegate.markers != markers;
}

class SkipMarkerPill extends StatelessWidget {
  const SkipMarkerPill({
    super.key,
    required this.controller,
    required this.markers,
    required this.onSkipIntro,
    required this.onSkipOutro,
  });

  final PlaybackController controller;
  final SkipMarkers markers;
  final VoidCallback onSkipIntro;
  final VoidCallback onSkipOutro;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.positionListenable,
        controller.durationListenable,
      ]),
      builder: (_, _) {
        final pos = controller.positionListenable.value;
        final dur = controller.durationListenable.value;
        if (markers.inIntro(pos, dur)) {
          return SoftButton(
            key: const ValueKey('skip-intro-pill'),
            label: '跳过片头',
            icon: Icons.fast_forward_rounded,
            onPressed: onSkipIntro,
          );
        }
        if (markers.inOutro(pos, dur)) {
          return SoftButton(
            key: const ValueKey('skip-outro-pill'),
            label: '跳过片尾',
            icon: Icons.skip_next_rounded,
            onPressed: onSkipOutro,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class AutoNextOverlay extends StatelessWidget {
  const AutoNextOverlay({
    super.key,
    required this.nextEpisode,
    required this.secondsLeft,
    required this.onPlayNow,
    required this.onCancel,
  });

  final Episode nextEpisode;
  final int secondsLeft;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Panel(
    key: const ValueKey('auto-next-overlay'),
    child: Padding(
      padding: const EdgeInsets.all(SpacingTokens.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$secondsLeft 秒后播放下一集',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            nextEpisode.title.isEmpty
                ? nextEpisode.label
                : '${nextEpisode.label} · ${nextEpisode.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SpacingTokens.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftButton(
                label: '立即播放',
                style: SoftStyle.accent,
                onPressed: onPlayNow,
              ),
              const SizedBox(width: SpacingTokens.xs),
              SoftButton(
                label: '取消',
                style: SoftStyle.clear,
                onPressed: onCancel,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class PlayerViewport extends StatelessWidget {
  const PlayerViewport({
    super.key,
    required this.candidate,
    required this.controller,
    required this.surface,
    required this.full,
    required this.controls,
    required this.locked,
    required this.inPip,
    required this.supportsPip,
    required this.danmakuEnabled,
    required this.drawerOpen,
    required this.switching,
    required this.failedLabels,
    required this.skipMarkers,
    this.backendError,
    this.brightness,
    this.gestureHint,
    this.autoNextEpisode,
    this.autoNextSeconds = 0,
    this.drawerBuilder,
    required this.onBack,
    required this.onEnterPip,
    required this.onOpenSettings,
    required this.onCloseDrawer,
    required this.onRetry,
    required this.onSwitchSource,
    required this.onToggleControls,
    required this.onToggleLock,
    required this.onSkipSeconds,
    required this.onRateHold,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
    required this.onSeek,
    required this.onTogglePlayback,
    required this.onToggleDanmaku,
    required this.onOpenComposer,
    required this.onKeepControlsVisible,
    required this.onScheduleHideControls,
    required this.onToggleFullscreen,
    required this.onPlayNext,
    required this.onPlayNextNow,
    required this.onCancelAutoNext,
    required this.onSkipIntro,
    required this.onSkipOutro,
    required this.onOpenEpisodes,
    required this.onOpenSpeed,
    required this.onOpenSubtitles,
    this.onPlayPrevious,
  });

  final MediaCandidate candidate;
  final PlaybackController? controller;
  final Widget? surface;
  final bool full;
  final bool controls;
  final bool locked;
  final bool inPip;
  final bool supportsPip;
  final bool danmakuEnabled;
  final bool drawerOpen;
  final bool switching;
  final List<String> failedLabels;
  final SkipMarkers skipMarkers;
  final String? backendError;
  final double? brightness;
  final String? gestureHint;
  final Episode? autoNextEpisode;
  final int autoNextSeconds;
  final WidgetBuilder? drawerBuilder;
  final VoidCallback onBack;
  final VoidCallback onEnterPip;
  final VoidCallback onOpenSettings;
  final VoidCallback onCloseDrawer;
  final VoidCallback onRetry;
  final VoidCallback onSwitchSource;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleLock;
  final void Function(int seconds) onSkipSeconds;
  final void Function(bool start) onRateHold;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onOpenComposer;
  final VoidCallback onKeepControlsVisible;
  final VoidCallback onScheduleHideControls;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayNextNow;
  final VoidCallback onCancelAutoNext;
  final VoidCallback onSkipIntro;
  final VoidCallback onSkipOutro;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenSubtitles;
  final VoidCallback? onPlayPrevious;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    final showDrawer =
        full && drawerOpen && !inPip && !locked && drawerBuilder != null;
    final showHeader =
        !inPip && !showDrawer && ((controls && !locked) || backendError != null);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (activeController != null) ...[
          ValueListenableBuilder(
            valueListenable: activeController,
            builder: (_, state, child) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: AspectRatio(aspectRatio: state.aspectRatio, child: child),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (surface != null) RepaintBoundary(child: surface!),
                PlayerOverlays(media: candidate, controller: activeController),
              ],
            ),
          ),
          PlayerGestureLayer(
            controller: activeController,
            full: full,
            locked: locked,
            controlsVisible: controls && !showDrawer,
            inPip: inPip,
            brightness: brightness,
            gestureHint: gestureHint,
            onToggleControls: onToggleControls,
            onToggleLock: onToggleLock,
            onSkip: onSkipSeconds,
            onRateHold: onRateHold,
            onBrightnessChanged: onBrightnessChanged,
            onVolumeChanged: onVolumeChanged,
            onSeekCommit: (pos) => onSeek(pos),
          ),
        ],
        if (showHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PlayerHeader(
              candidate: candidate,
              full: full,
              danmakuEnabled: danmakuEnabled,
              supportsPip: supportsPip && !locked,
              onEnterPip: onEnterPip,
              onToggleDanmaku: onToggleDanmaku,
              onOpenComposer: onOpenComposer,
              onOpenSettings: activeController == null ? null : onOpenSettings,
              onBack: onBack,
            ),
          ),
        if (backendError != null)
          PlayerErrorPanel(
            message: backendError!,
            switching: switching,
            failedLabels: failedLabels,
            onRetry: onRetry,
            onSwitchSource: onSwitchSource,
          ),
        if (activeController == null && backendError == null)
          const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在打开视频'),
          ),
        if (activeController != null)
          ValueListenableBuilder<PlaybackViewState>(
            valueListenable: activeController,
            builder: (_, state, _) {
              if (state.error case final error?) {
                return PlayerErrorPanel(
                  message: error,
                  switching: switching,
                  failedLabels: failedLabels,
                  onRetry: onRetry,
                  onSwitchSource: onSwitchSource,
                );
              }
              if (state.opening) {
                return const Center(
                  child: CircularProgressIndicator(semanticsLabel: '正在打开视频'),
                );
              }
              final showFooter =
                  !inPip &&
                  !locked &&
                  !showDrawer &&
                  (controls || state.completed);
              final bottomGap = showFooter
                  ? (full ? 116.0 : 66.0)
                  : SpacingTokens.md;
              return Stack(
                children: [
                  if (state.buffering)
                    const IgnorePointer(
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: '正在缓冲',
                        ),
                      ),
                    ),
                  if (!inPip && !locked && autoNextEpisode != null)
                    Positioned(
                      right: SpacingTokens.md,
                      bottom: bottomGap,
                      child: AutoNextOverlay(
                        nextEpisode: autoNextEpisode!,
                        secondsLeft: autoNextSeconds,
                        onPlayNow: onPlayNextNow,
                        onCancel: onCancelAutoNext,
                      ),
                    )
                  else if (!inPip && !locked && !skipMarkers.isEmpty)
                    Positioned(
                      right: SpacingTokens.md,
                      bottom: bottomGap,
                      child: SkipMarkerPill(
                        controller: activeController,
                        markers: skipMarkers,
                        onSkipIntro: onSkipIntro,
                        onSkipOutro: onSkipOutro,
                      ),
                    ),
                  if (showFooter)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PlayerControlsFooter(
                        controller: activeController,
                        state: state,
                        full: full,
                        danmakuEnabled: danmakuEnabled,
                        skipMarkers: skipMarkers,
                        candidate: candidate,
                        onTogglePlayback: onTogglePlayback,
                        onSeek: onSeek,
                        onKeepControlsVisible: onKeepControlsVisible,
                        onScheduleHideControls: onScheduleHideControls,
                        onToggleFullscreen: onToggleFullscreen,
                        onToggleDanmaku: onToggleDanmaku,
                        onOpenComposer: onOpenComposer,
                        onPlayNext: onPlayNext,
                        onPlayPrevious: onPlayPrevious,
                        onOpenEpisodes: onOpenEpisodes,
                        onOpenSpeed: onOpenSpeed,
                        onOpenSubtitles: onOpenSubtitles,
                        onToggleLock: onToggleLock,
                        onSkipSeconds: onSkipSeconds,
                        onSwitchSource: onSwitchSource,
                        onOpenSettings: onOpenSettings,
                      ),
                    ),
                ],
              );
            },
          ),
        if (showDrawer)
          Positioned.fill(
            key: const ValueKey('player-right-drawer'),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final drawerWidth = math.min(360.0, bounds.maxWidth * 0.56);
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onCloseDrawer,
                        child: const ColoredBox(color: Colors.black26),
                      ),
                    ),
                    SizedBox(
                      width: drawerWidth,
                      child: LiquidGlassSurface(
                        radius: const BorderRadius.horizontal(
                          left: Radius.circular(24),
                        ),
                        blur: 22,
                        elevated: true,
                        child: Material(
                          type: MaterialType.transparency,
                          child: SafeArea(
                            left: false,
                            child: drawerBuilder!(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class PlayerScreenScaffold extends StatelessWidget {
  const PlayerScreenScaffold({
    super.key,
    required this.full,
    required this.fullScreen,
    required this.viewport,
    required this.details,
    required this.onExitFullscreen,
  });

  final bool full;
  final bool fullScreen;
  final Widget viewport;
  final Widget details;
  final VoidCallback onExitFullscreen;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !full,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && full) onExitFullscreen();
    },
    child: Scaffold(
      backgroundColor: fullScreen
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      body: fullScreen
          ? viewport
          : AdaptiveLayout.useWideTheatre(context)
          ? SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: RadiusTokens.hero,
                            child: viewport,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.md),
                    SizedBox(
                      width: AdaptiveLayout.isPad(context) ? 380 : 360,
                      child: LiquidGlassSurface(
                        radius: RadiusTokens.panel,
                        blur: 16,
                        child: ClipRRect(
                          borderRadius: RadiusTokens.panel,
                          child: Material(
                            type: MaterialType.transparency,
                            child: details,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: viewport),
                  Expanded(child: details),
                ],
              ),
            ),
    ),
  );
}
