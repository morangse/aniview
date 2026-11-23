import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../media/playback_controller.dart';
import 'player_controls_bar.dart';

enum _DragMode { none, brightness, volume, seek }

class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    super.key,
    required this.controller,
    required this.full,
    required this.locked,
    required this.controlsVisible,
    required this.inPip,
    required this.brightness,
    this.gestureHint,
    required this.onToggleControls,
    required this.onToggleLock,
    required this.onSkip,
    required this.onRateHold,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
    required this.onSeekCommit,
  });

  final PlaybackController controller;
  final bool full;
  final bool locked;
  final bool controlsVisible;
  final bool inPip;
  final double? brightness;
  final String? gestureHint;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleLock;
  final void Function(int seconds) onSkip;
  final void Function(bool start) onRateHold;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<Duration> onSeekCommit;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  double _doubleTapX = 0;
  _DragMode _dragMode = _DragMode.none;
  double _dragStartX = 0;
  double _dragAccumX = 0;
  double _dragAccumY = 0;
  double _dragStartBrightness = 0.5;
  double _dragStartVolume = 100;
  int _dragStartSeekMs = 0;
  int? _seekPreviewMs;
  String? _dragHint;
  double? _dragProgress;
  bool _dragBoost = false;
  bool _lockButtonVisible = false;
  Timer? _lockHideTimer;

  @override
  void didUpdateWidget(PlayerGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked && !oldWidget.locked) {
      _clearDragState();
      _showLockBriefly();
    } else if (!widget.locked && oldWidget.locked) {
      _lockHideTimer?.cancel();
      _lockButtonVisible = false;
    }
  }

  @override
  void dispose() {
    _lockHideTimer?.cancel();
    super.dispose();
  }

  void _showLockBriefly() {
    _lockHideTimer?.cancel();
    setState(() => _lockButtonVisible = true);
    _lockHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lockButtonVisible = false);
    });
  }

  void _handleLockedTap() {
    HapticFeedback.selectionClick();
    _showLockBriefly();
  }

  void _handleVerticalStart(DragStartDetails details, BoxConstraints bounds) {
    _dragStartX = details.localPosition.dx;
    _dragAccumY = 0;
    if (_dragStartX < bounds.maxWidth / 2) {
      _dragMode = _DragMode.brightness;
      _dragStartBrightness = widget.brightness ?? 0.5;
    } else {
      _dragMode = _DragMode.volume;
      _dragStartVolume = widget.controller.value.volume;
    }
  }

  void _handleVerticalUpdate(DragUpdateDetails details, BoxConstraints bounds) {
    final range = math.max(120.0, bounds.maxHeight * 0.75);
    _dragAccumY += details.delta.dy;
    if (_dragMode == _DragMode.brightness) {
      final next = (_dragStartBrightness - _dragAccumY / range).clamp(0.0, 1.0);
      setState(() {
        _dragHint = '亮度 ${(next * 100).round()}%';
        _dragProgress = next;
        _dragBoost = false;
      });
      widget.onBrightnessChanged(next);
    } else if (_dragMode == _DragMode.volume) {
      final next = (_dragStartVolume - (_dragAccumY / range) * 150.0).clamp(
        0.0,
        150.0,
      );
      setState(() {
        _dragHint = '音量 ${next.round()}%';
        _dragProgress = (next / 150).clamp(0.0, 1.0);
        _dragBoost = next > 100;
      });
      widget.onVolumeChanged(next);
    }
  }

  void _handleHorizontalStart(DragStartDetails details) {
    final duration = widget.controller.durationListenable.value;
    if (!widget.controller.value.ready || duration <= Duration.zero) {
      _dragMode = _DragMode.none;
      return;
    }
    _dragMode = _DragMode.seek;
    _dragAccumX = 0;
    _dragStartSeekMs = widget.controller.positionListenable.value.inMilliseconds;
    _seekPreviewMs = _dragStartSeekMs;
  }

  void _handleHorizontalUpdate(
    DragUpdateDetails details,
    BoxConstraints bounds,
  ) {
    if (_dragMode != _DragMode.seek) return;
    final durationMs = widget.controller.durationListenable.value.inMilliseconds;
    if (durationMs <= 0) return;
    final width = math.max(160.0, bounds.maxWidth);
    final spanMs = durationMs < 30000
        ? durationMs.toDouble()
        : (durationMs * 0.4).clamp(30000.0, 180000.0);
    _dragAccumX += details.delta.dx;
    final deltaMs = (_dragAccumX / width * spanMs).round();
    final targetMs = (_dragStartSeekMs + deltaMs).clamp(0, durationMs);
    final diffSec = ((targetMs - _dragStartSeekMs) / 1000).round();
    final diffLabel = diffSec >= 0 ? '+${diffSec}s' : '${diffSec}s';
    setState(() {
      _seekPreviewMs = targetMs;
      _dragProgress = (targetMs / durationMs).clamp(0.0, 1.0);
      _dragBoost = false;
      _dragHint =
          '${formatPlaybackTime(Duration(milliseconds: targetMs))} / ${formatPlaybackTime(Duration(milliseconds: durationMs))} ($diffLabel)';
    });
  }

  void _handleDragEnd() {
    if (_dragMode == _DragMode.seek && _seekPreviewMs != null) {
      widget.onSeekCommit(Duration(milliseconds: _seekPreviewMs!));
    }
    _clearDragState();
  }

  void _clearDragState() {
    if (_dragMode == _DragMode.none &&
        _dragHint == null &&
        _seekPreviewMs == null) {
      return;
    }
    setState(() {
      _dragMode = _DragMode.none;
      _dragHint = null;
      _dragProgress = null;
      _dragBoost = false;
      _seekPreviewMs = null;
    });
  }

  Widget _buildHud() {
    final activeDrag = _dragMode != _DragMode.none && _dragHint != null;
    final text = activeDrag ? _dragHint! : widget.gestureHint!;
    var alignment = Alignment.center;
    var icon = Icons.info_outline_rounded;
    if (activeDrag) {
      icon = switch (_dragMode) {
        _DragMode.brightness => Icons.brightness_6_rounded,
        _DragMode.volume =>
          _dragProgress == 0
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
        _DragMode.seek => Icons.fast_forward_rounded,
        _DragMode.none => Icons.info_outline_rounded,
      };
    } else if (text.contains('快退')) {
      alignment = const Alignment(-0.52, 0);
      icon = Icons.fast_rewind_rounded;
    } else if (text.contains('快进')) {
      alignment = const Alignment(0.52, 0);
      icon = Icons.fast_forward_rounded;
    } else if (text.contains('倍速')) {
      alignment = const Alignment(0, -0.58);
      icon = Icons.speed_rounded;
    }

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: LiquidGlassSurface(
          key: const ValueKey('player-hud'),
          radius: RadiusTokens.pill,
          blur: 16,
          elevated: true,
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
            vertical: SpacingTokens.xs,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 112, maxWidth: 230),
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: _dragBoost
                            ? ColorTokens.accent
                            : ColorTokens.text,
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_dragProgress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: _dragProgress,
                        color: _dragBoost ? ColorTokens.accent : Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inPip) return const SizedBox.shrink();
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final hasHud = (_dragMode != _DragMode.none && _dragHint != null) ||
        widget.gestureHint != null;
    final showLockButton =
        widget.full &&
        (widget.locked
            ? _lockButtonVisible
            : (!AdaptiveLayout.isApplePlatform && widget.controlsVisible));

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          left: insets.left + SpacingTokens.md,
          right: insets.right + SpacingTokens.md,
          child: LayoutBuilder(
            builder: (context, bounds) => GestureDetector(
              key: const ValueKey('player-gesture-area'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.locked ? _handleLockedTap : widget.onToggleControls,
              onDoubleTapDown: widget.locked
                  ? null
                  : (details) => _doubleTapX = details.localPosition.dx,
              onDoubleTap: widget.locked
                  ? null
                  : () => widget.onSkip(
                      _doubleTapX < bounds.maxWidth / 2 ? -10 : 10,
                    ),
              onLongPressStart: widget.locked
                  ? null
                  : (_) {
                      HapticFeedback.lightImpact();
                      widget.onRateHold(true);
                    },
              onLongPressEnd: widget.locked
                  ? null
                  : (_) => widget.onRateHold(false),
              onLongPressCancel: widget.locked
                  ? null
                  : () => widget.onRateHold(false),
              onVerticalDragStart: widget.locked
                  ? null
                  : (details) => _handleVerticalStart(details, bounds),
              onVerticalDragUpdate: widget.locked
                  ? null
                  : (details) => _handleVerticalUpdate(details, bounds),
              onVerticalDragEnd: widget.locked ? null : (_) => _handleDragEnd(),
              onVerticalDragCancel: widget.locked ? null : _clearDragState,
              onHorizontalDragStart: widget.locked
                  ? null
                  : _handleHorizontalStart,
              onHorizontalDragUpdate: widget.locked
                  ? null
                  : (details) => _handleHorizontalUpdate(details, bounds),
              onHorizontalDragEnd: widget.locked
                  ? null
                  : (_) => _handleDragEnd(),
              onHorizontalDragCancel: widget.locked ? null : _clearDragState,
            ),
          ),
        ),
        if (hasHud) _buildHud(),
        if (showLockButton)
          Align(
            alignment: Alignment.centerLeft,
            child: SafeArea(
              right: false,
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: SpacingTokens.sm),
                child: LiquidGlassSurface(
                  radius: RadiusTokens.pill,
                  blur: 14,
                  child: Material(
                    type: MaterialType.transparency,
                    child: IconButton(
                      key: const ValueKey('player-lock-button'),
                      color: Colors.white,
                      icon: Icon(
                        widget.locked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                      ),
                      tooltip: widget.locked ? '解锁' : '锁屏',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onToggleLock();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
