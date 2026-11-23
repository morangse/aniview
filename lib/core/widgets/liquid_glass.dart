import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'soft_controls.dart';

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.radius = RadiusTokens.panel,
    this.blur = 18.0,
    this.elevated = false,
    this.tint,
    this.padding,
    this.borderWidth = 1.0,
  });

  final Widget child;
  final BorderRadius radius;
  final double blur;
  final bool elevated;
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final effectiveBlur = reduceMotion ? 0.0 : blur;
    final baseTint =
        tint ?? (elevated ? ColorTokens.glassElevated : ColorTokens.glassTint);
    final darkerTint = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.14),
      baseTint,
    );

    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: elevated ? 0.14 : 0.09),
              baseTint,
            ),
            baseTint,
            darkerTint,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: ColorTokens.glassBorder,
          width: borderWidth,
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      ColorTokens.glassSpecularTop,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (padding != null) Padding(padding: padding!, child: child) else child,
        ],
      ),
    );

    final clipped = ClipRRect(
      borderRadius: radius,
      child: effectiveBlur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveBlur,
                sigmaY: effectiveBlur,
              ),
              child: body,
            )
          : body,
    );

    if (!elevated) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: ShadowTokens.floating,
      ),
      child: clipped,
    );
  }
}

class LiquidGlassLensDecoration extends StatelessWidget {
  const LiquidGlassLensDecoration({
    super.key,
    this.radius = RadiusTokens.pill,
  });

  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ColorTokens.glassSpecularTop.withValues(alpha: 0.34),
          ColorTokens.glassLens,
          ColorTokens.glassSpecularBottom,
        ],
      ),
      border: Border.all(
        color: ColorTokens.accent.withValues(alpha: 0.42),
        width: 0.85,
      ),
    ),
  );
}

class LiquidGlassSegmentedBar extends StatelessWidget {
  const LiquidGlassSegmentedBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedIndex.clamp(0, labels.length - 1);
    final duration = MotionTokens.resolve(
      context,
      const Duration(milliseconds: 220),
    );
    return LiquidGlassSurface(
      radius: RadiusTokens.pill,
      blur: 14,
      padding: const EdgeInsets.all(SpacingTokens.xxs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  left: width * safeIndex,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: const LiquidGlassLensDecoration(),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i != selectedIndex) {
                              HapticFeedback.selectionClick();
                            }
                            onSelect(i);
                          },
                          child: Center(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(
                                    color: i == selectedIndex
                                        ? ColorTokens.text
                                        : ColorTokens.muted,
                                  ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class LiquidGlassRail extends StatelessWidget {
  const LiquidGlassRail({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, '首页'),
    (Icons.explore_outlined, Icons.explore_rounded, '发现'),
    (Icons.bookmark_border_rounded, Icons.bookmark_rounded, '追番'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  static const _itemHeight = 68.0;

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, _items.length - 1);
    final duration = MotionTokens.resolve(
      context,
      const Duration(milliseconds: 220),
    );
    return SizedBox(
      width: LayoutTokens.railWidth,
      child: LiquidGlassSurface(
        radius: RadiusTokens.hero,
        blur: 20,
        elevated: true,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xs,
          vertical: SpacingTokens.sm,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: SpacingTokens.sm),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: ColorTokens.accent,
                  size: 24,
                ),
              ),
              SizedBox(
                height: _itemHeight * _items.length,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      top: safeIndex * _itemHeight + 2,
                      left: 0,
                      right: 0,
                      height: _itemHeight - 4,
                      child: const LiquidGlassLensDecoration(
                        radius: RadiusTokens.card,
                      ),
                    ),
                    Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          SizedBox(
                            height: _itemHeight,
                            width: double.infinity,
                            child: SoftAction(
                              key: ValueKey('nav-$i'),
                              selected: i == safeIndex,
                              style: SoftStyle.clear,
                              radius: RadiusTokens.card,
                              onPressed: () => onSelect(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    i == safeIndex ? _items[i].$2 : _items[i].$1,
                                    size: 23,
                                    color: i == safeIndex
                                        ? ColorTokens.accent
                                        : ColorTokens.muted,
                                  ),
                                  const SizedBox(height: SpacingTokens.xxs),
                                  Text(
                                    _items[i].$3,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          color: i == safeIndex
                                              ? ColorTokens.text
                                              : ColorTokens.muted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
