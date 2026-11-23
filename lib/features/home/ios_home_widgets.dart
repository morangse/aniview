import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../media/media.dart';
import '../anime/anime.dart';
import '../player/player_controls_bar.dart';
import '../player/source_sheet.dart';

class IosSectionHeader extends StatelessWidget {
  const IosSectionHeader({
    super.key,
    required this.title,
    this.countLabel,
    this.onTapAction,
  });

  final String title;
  final String? countLabel;
  final VoidCallback? onTapAction;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onTapAction != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTapAction!();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.xxs,
                  vertical: SpacingTokens.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countLabel ?? '查看全部',
                      style: type.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class IosPosterCard extends StatefulWidget {
  const IosPosterCard({super.key, required this.anime});

  final Anime anime;

  static double cardWidth(BuildContext context) =>
      AdaptiveLayout.isPad(context) ? 148.0 : 110.0;

  static double cardHeight(BuildContext context) =>
      AdaptiveLayout.isPad(context) ? 268.0 : 210.0;

  @override
  State<IosPosterCard> createState() => _IosPosterCardState();
}

class _IosPosterCardState extends State<IosPosterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final type = Theme.of(context).textTheme;
    final isPad = AdaptiveLayout.isPad(context);
    final subMeta = [
      if (anime.year case final y? when y.isNotEmpty) y,
      if ((anime.year == null || anime.year!.isEmpty) &&
          anime.platform.isNotEmpty)
        anime.platform,
    ].join(' · ');

    return Semantics(
      button: true,
      label: anime.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/anime/${anime.id}', extra: anime);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: MotionTokens.resolve(context, MotionTokens.press),
          curve: MotionTokens.curve,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isPad ? 14 : 12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x45000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isPad ? 14 : 12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Artwork(
                          uri: anime.cover,
                          decodeWidth: isPad ? 380 : 280,
                          alignment: Alignment.topCenter,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.62, 1.0],
                              colors: [Colors.transparent, Color(0x99070D14)],
                            ),
                          ),
                        ),
                        if (anime.episodeCount case final epCount?)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: LiquidGlassSurface(
                              radius: RadiusTokens.pill,
                              blur: 10,
                              tint: const Color(0x94163A66),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              child: Text(
                                '$epCount',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (anime.score case final score?)
                          Positioned(
                            bottom: 6,
                            right: 8,
                            child: Text(
                              score.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  isPad ? 14 : 12,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  width: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                anime.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (isPad ? type.titleSmall : type.labelLarge)?.copyWith(
                      color: ColorTokens.text,
                      fontWeight: FontWeight.w600,
                      fontSize: isPad ? 13.5 : 12.5,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                subMeta.isEmpty ? ' ' : subMeta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: isPad ? 11.5 : 11.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IosContinueCard extends StatelessWidget {
  const IosContinueCard({super.key, required this.entry});

  final WatchEntry entry;

  static double cardWidth(BuildContext context) =>
      AdaptiveLayout.isPad(context) ? 228.0 : 172.0;

  static double cardHeight(BuildContext context) =>
      AdaptiveLayout.isPad(context) ? 182.0 : 148.0;

  @override
  Widget build(BuildContext context) {
    final isPad = AdaptiveLayout.isPad(context);
    final type = Theme.of(context).textTheme;
    final sub = [
      entry.media.episodeLabel,
      if (entry.progress.duration > Duration.zero)
        '剩余 ${formatPlaybackTime(entry.progress.duration - entry.progress.position)}'
      else
        '${(entry.progress.fraction * 100).round()}%',
    ].nonNulls.join(' · ');

    return SizedBox(
      width: cardWidth(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/player/${entry.media.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isPad ? 14 : 12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Artwork(
                      uri: entry.media.cover,
                      asset: entry.media.cover == null ? localArtwork : null,
                      alignment: Alignment.topCenter,
                      decodeWidth: 460,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1.0],
                          colors: [Colors.transparent, Color(0xB8080F17)],
                        ),
                      ),
                    ),
                    Center(
                      child: LiquidGlassSurface(
                        radius: RadiusTokens.pill,
                        blur: 10,
                        tint: const Color(0x66111B26),
                        padding: const EdgeInsets.all(7),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        minHeight: 3.5,
                        value: entry.progress.fraction.clamp(0.02, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6BB5FF),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              isPad ? 14 : 12,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                              width: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: ColorTokens.text,
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IosEmptyContinueCard extends StatelessWidget {
  const IosEmptyContinueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => showSources(context),
      child: LiquidGlassSurface(
        radius: RadiusTokens.card,
        blur: 16,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: Color(0xFF6BB5FF),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('暂无继续观看的影片', style: type.titleSmall),
                  Text('从本地文件或播放地址开始', style: type.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ColorTokens.muted),
          ],
        ),
      ),
    );
  }
}
