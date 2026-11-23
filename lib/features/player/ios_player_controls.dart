import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../media/media.dart';
import '../../media/playback_controller.dart';
import '../../media/sources/release_title_parser.dart';

String _formatRateBadge(double value) =>
    value % 1 == 0 ? '${value.toInt()}×' : '$value×';

class IosFullscreenHeader extends StatelessWidget {
  const IosFullscreenHeader({
    super.key,
    required this.candidate,
    required this.danmakuEnabled,
    required this.supportsPip,
    required this.onBack,
    this.onEnterPip,
    this.onToggleDanmaku,
    this.onOpenComposer,
    this.onOpenSettings,
  });

  final MediaCandidate candidate;
  final bool danmakuEnabled;
  final bool supportsPip;
  final VoidCallback onBack;
  final VoidCallback? onEnterPip;
  final VoidCallback? onToggleDanmaku;
  final VoidCallback? onOpenComposer;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final subTitle = candidate.episodeLabel;
    final fullTitle = subTitle == null || subTitle.isEmpty
        ? candidate.title
        : '${candidate.title}  $subTitle';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB8000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.sm,
            SpacingTokens.xs,
            SpacingTokens.sm,
            SpacingTokens.md,
          ),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('ios-player-close'),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: '退出全屏',
                onPressed: onBack,
              ),
              const SizedBox(width: SpacingTokens.xxs),
              Expanded(
                child: Text(
                  fullTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
              if (supportsPip && onEnterPip != null)
                IconButton(
                  key: const ValueKey('pip-button'),
                  icon: const Icon(
                    Icons.picture_in_picture_alt_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  tooltip: '画中画',
                  onPressed: onEnterPip,
                ),
              if (onToggleDanmaku != null)
                IconButton(
                  key: const ValueKey('danmaku-quick-toggle'),
                  icon: Icon(
                    danmakuEnabled
                        ? Icons.subtitles_rounded
                        : Icons.subtitles_off_outlined,
                    color: danmakuEnabled
                        ? const Color(0xFF6BB5FF)
                        : Colors.white70,
                    size: 22,
                  ),
                  tooltip: danmakuEnabled ? '关闭弹幕' : '开启弹幕',
                  onPressed: onToggleDanmaku,
                ),
              if (onOpenComposer != null)
                IconButton(
                  key: const ValueKey('danmaku-send-button'),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: '发弹幕',
                  onPressed: onOpenComposer,
                ),
              if (onOpenSettings != null)
                IconButton(
                  key: const ValueKey('player-settings-button'),
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  tooltip: '设置',
                  onPressed: onOpenSettings,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class IosFullscreenFooter extends StatelessWidget {
  const IosFullscreenFooter({
    super.key,
    required this.candidate,
    required this.state,
    required this.timeline,
    required this.danmakuEnabled,
    required this.onTogglePlayback,
    required this.onToggleFullscreen,
    required this.onToggleDanmaku,
    required this.onOpenEpisodes,
    required this.onOpenSpeed,
    required this.onOpenSubtitles,
    this.onToggleLock,
    this.onSkipSeconds,
    this.onPlayPrevious,
    required this.onPlayNext,
    this.onSwitchSource,
    this.onOpenSettings,
  });

  final MediaCandidate? candidate;
  final PlaybackViewState state;
  final Widget timeline;
  final bool danmakuEnabled;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenSubtitles;
  final VoidCallback? onToggleLock;
  final void Function(int seconds)? onSkipSeconds;
  final VoidCallback? onPlayPrevious;
  final VoidCallback onPlayNext;
  final VoidCallback? onSwitchSource;
  final VoidCallback? onOpenSettings;

  List<String> _resolveTags() {
    final sourceName = candidate?.sourceName ?? '';
    if (sourceName.isEmpty) return const [];
    final tags = ReleaseTitleParser.parse(sourceName).displayTags;
    if (tags.isNotEmpty) return tags;
    final clean = sourceName.split('/').last.split('\\').last.trim();
    return clean.isEmpty ? const [] : [clean];
  }

  static bool _isHighlightTag(String tag) {
    final upper = tag.toUpperCase();
    return upper.contains('HEVC') ||
        upper.contains('HDR') ||
        upper.contains('10BIT') ||
        upper.contains('4K') ||
        upper.contains('2160P');
  }

  @override
  Widget build(BuildContext context) {
    final tags = _resolveTags();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.lg,
            SpacingTokens.lg,
            SpacingTokens.lg,
            SpacingTokens.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.storageError)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '本次观看进度暂时无法保存。',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: tags.isEmpty
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < tags.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  Text(
                                    tags[i],
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _isHighlightTag(tags[i])
                                          ? const Color(0xFFE6B566)
                                          : Colors.white.withValues(alpha: 0.78),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  _MiniPlayerIcon(
                    icon: Icons.subtitles_outlined,
                    tooltip: danmakuEnabled ? '关闭弹幕' : '开启弹幕',
                    active: danmakuEnabled,
                    onPressed: onToggleDanmaku,
                  ),
                  _MiniPlayerIcon(
                    icon: Icons.closed_caption_outlined,
                    tooltip: '字幕音轨',
                    onPressed: onOpenSubtitles,
                  ),
                  _MiniPlayerTextPill(
                    label: _formatRateBadge(state.rate),
                    onPressed: onOpenSpeed,
                  ),
                  if (onSwitchSource != null)
                    _MiniPlayerIcon(
                      icon: Icons.swap_horiz_rounded,
                      tooltip: '切换片源',
                      onPressed: onSwitchSource!,
                    ),
                  if (onOpenSettings != null)
                    _MiniPlayerIcon(
                      icon: Icons.more_horiz_rounded,
                      tooltip: '更多设置',
                      onPressed: onOpenSettings!,
                    ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.8,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: timeline,
              ),
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: onToggleLock != null
                          ? IconButton(
                              key: const ValueKey('player-lock-button'),
                              icon: const Icon(
                                Icons.lock_open_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                              tooltip: '锁屏',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onToggleLock!();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onPlayPrevious != null)
                          _TransportIcon(
                            icon: Icons.skip_previous_rounded,
                            tooltip: '上一集',
                            onPressed: onPlayPrevious!,
                          ),
                        _TransportIcon(
                          icon: Icons.replay_10_rounded,
                          tooltip: '快退 10 秒',
                          onPressed: () => onSkipSeconds?.call(-10),
                        ),
                        IconButton(
                          key: const ValueKey('toggle-playback'),
                          iconSize: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          icon: Icon(
                            state.completed
                                ? Icons.replay_rounded
                                : state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          tooltip: state.completed
                              ? '重播'
                              : state.playing
                              ? '暂停'
                              : '播放',
                          onPressed: onTogglePlayback,
                        ),
                        _TransportIcon(
                          icon: Icons.forward_10_rounded,
                          tooltip: '快进 10 秒',
                          onPressed: () => onSkipSeconds?.call(10),
                        ),
                        _TransportIcon(
                          icon: Icons.skip_next_rounded,
                          tooltip: '下一集',
                          onPressed: onPlayNext,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TransportIcon(
                        icon: Icons.playlist_play_rounded,
                        tooltip: '选集',
                        onPressed: onOpenEpisodes,
                      ),
                      _TransportIcon(
                        icon: Icons.fullscreen_exit_rounded,
                        tooltip: '退出全屏',
                        onPressed: onToggleFullscreen,
                      ),
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

class _MiniPlayerIcon extends StatelessWidget {
  const _MiniPlayerIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => IconButton(
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    padding: const EdgeInsets.all(6),
    iconSize: 19,
    icon: Icon(
      icon,
      color: active ? const Color(0xFF6BB5FF) : Colors.white.withValues(alpha: 0.88),
    ),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

class _MiniPlayerTextPill extends StatelessWidget {
  const _MiniPlayerTextPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: RadiusTokens.pill,
        border: Border.all(color: Colors.white38, width: 0.9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: const EdgeInsets.all(4),
    iconSize: 24,
    icon: Icon(icon, color: Colors.white),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
