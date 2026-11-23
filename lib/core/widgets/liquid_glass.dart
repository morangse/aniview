import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'soft_controls.dart';

class _LiquidGlassRimPainter extends CustomPainter {
  const _LiquidGlassRimPainter({
    required this.radius,
    this.strokeWidth = 0.85,
    this.topAlpha = 0.44,
    this.bottomAlpha = 0.20,
    this.oval = false,
  });

  final BorderRadius radius;
  final double strokeWidth;
  final double topAlpha;
  final double bottomAlpha;
  final bool oval;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final inset = strokeWidth * 0.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: topAlpha),
          Colors.white.withValues(alpha: topAlpha * 0.24),
          ColorTokens.accent.withValues(alpha: bottomAlpha * 0.65),
          Colors.white.withValues(alpha: bottomAlpha),
        ],
        stops: const [0.0, 0.34, 0.68, 1.0],
      ).createShader(rect);

    if (oval) {
      canvas.drawOval(rect.deflate(inset), paint);
      return;
    }
    final rrect = radius.toRRect(rect).deflate(inset);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.topAlpha != topAlpha ||
      oldDelegate.bottomAlpha != bottomAlpha ||
      oldDelegate.oval != oval;
}

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
    this.opticalRim,
  });

  final Widget child;
  final BorderRadius radius;
  final double blur;
  final bool elevated;
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final double borderWidth;
  final bool? opticalRim;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final effectiveBlur = reduceMotion ? 0.0 : blur;
    final useOptical = opticalRim ?? AdaptiveLayout.isApplePlatform;
    final baseTint =
        tint ??
        (useOptical
            ? (elevated
                  ? const Color(0x7C121D29)
                  : const Color(0x64121D29))
            : (elevated ? ColorTokens.glassElevated : ColorTokens.glassTint));
    final darkerTint = Color.alphaBlend(
      Colors.black.withValues(alpha: useOptical ? 0.16 : 0.14),
      baseTint,
    );

    final innerContent = Stack(
      fit: StackFit.passthrough,
      children: [
        if (!useOptical)
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
    );

    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(
                alpha: useOptical
                    ? (elevated ? 0.15 : 0.11)
                    : (elevated ? 0.14 : 0.09),
              ),
              baseTint,
            ),
            baseTint,
            darkerTint,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: useOptical
            ? null
            : Border.all(
                color: ColorTokens.glassBorder,
                width: borderWidth,
              ),
      ),
      child: useOptical
          ? CustomPaint(
              foregroundPainter: _LiquidGlassRimPainter(
                radius: radius,
                strokeWidth: 0.85,
                topAlpha: elevated ? 0.46 : 0.36,
                bottomAlpha: elevated ? 0.22 : 0.16,
              ),
              child: innerContent,
            )
          : innerContent,
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
        boxShadow: useOptical
            ? const [
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ]
            : ShadowTokens.floating,
      ),
      child: clipped,
    );
  }
}

class LiquidGlassLensDecoration extends StatelessWidget {
  const LiquidGlassLensDecoration({
    super.key,
    this.radius = RadiusTokens.pill,
    this.optical = false,
  });

  final BorderRadius radius;
  final bool optical;

  @override
  Widget build(BuildContext context) {
    if (optical) {
      return CustomPaint(
        foregroundPainter: _LiquidGlassRimPainter(
          radius: radius,
          strokeWidth: 0.7,
          topAlpha: 0.36,
          bottomAlpha: 0.14,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.23),
                Colors.white.withValues(alpha: 0.11),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
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
}

class LiquidGlassCircleButton extends StatefulWidget {
  const LiquidGlassCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.activeColor,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final double iconSize;
  final Color? activeColor;
  final Color? tint;

  @override
  State<LiquidGlassCircleButton> createState() =>
      _LiquidGlassCircleButtonState();
}

class _LiquidGlassCircleButtonState extends State<LiquidGlassCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tint =
        widget.tint ??
        (widget.active
            ? Colors.white.withValues(alpha: 0.22)
            : const Color(0x66121D29));
    final iconColor = !enabled
        ? Colors.white38
        : widget.active
        ? (widget.activeColor ?? const Color(0xFF6BB5FF))
        : Colors.white;

    final interior = CustomPaint(
      foregroundPainter: _LiquidGlassRimPainter(
        radius: RadiusTokens.pill,
        strokeWidth: 0.85,
        topAlpha: widget.active ? 0.56 : 0.42,
        bottomAlpha: widget.active ? 0.28 : 0.16,
        oval: true,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(Colors.white.withValues(alpha: 0.16), tint),
              tint,
            ],
          ),
        ),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );

    final glass = ClipOval(
      child: reduceMotion
          ? interior
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: interior,
            ),
    );

    return Tooltip(
      message: widget.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.active,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: !enabled
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onPressed!();
                },
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: MotionTokens.resolve(context, MotionTokens.press),
            curve: MotionTokens.curve,
            child: glass,
          ),
        ),
      ),
    );
  }
}

class IosLiquidGlassDock extends StatelessWidget {
  const IosLiquidGlassDock({
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

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, _items.length - 1);
    final isPad = AdaptiveLayout.isWideLayout(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final capsuleWidth = isPad
        ? 368.0
        : math.min(viewportWidth - 40.0, 296.0).clamp(220.0, 296.0);
    final dockHeight = isPad ? 62.0 : 60.0;
    final innerHeight = dockHeight - 8.0;
    final duration = MotionTokens.resolve(
      context,
      const Duration(milliseconds: 260),
    );

    return SizedBox(
      width: capsuleWidth,
      child: LiquidGlassSurface(
        radius: RadiusTokens.pill,
        blur: 28,
        elevated: true,
        opticalRim: true,
        tint: const Color(0x7A111B26),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / _items.length;
            return SizedBox(
              height: innerHeight,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: itemWidth * safeIndex,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: const LiquidGlassLensDecoration(
                      radius: RadiusTokens.pill,
                      optical: true,
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (i) {
                      final (regular, active, label) = _items[i];
                      final selected = i == safeIndex;
                      final iconColor = selected
                          ? const Color(0xFF6BB5FF)
                          : Colors.white.withValues(alpha: 0.70);
                      final labelColor = selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.70);
                      return Expanded(
                        child: Semantics(
                          key: ValueKey('nav-$i'),
                          button: true,
                          selected: selected,
                          label: label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!selected) {
                                HapticFeedback.selectionClick();
                              }
                              onSelect(i);
                            },
                            child: Center(
                              child: AnimatedScale(
                                scale: selected ? 1.04 : 1.0,
                                duration: MotionTokens.resolve(
                                  context,
                                  const Duration(milliseconds: 180),
                                ),
                                curve: Curves.easeOutCubic,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selected ? active : regular,
                                      size: isPad ? 23 : 22,
                                      color: iconColor,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.15,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: labelColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
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
    final optical = AdaptiveLayout.isApplePlatform;
    final duration = MotionTokens.resolve(
      context,
      const Duration(milliseconds: 220),
    );
    return LiquidGlassSurface(
      radius: RadiusTokens.pill,
      blur: optical ? 20 : 14,
      opticalRim: optical,
      padding: const EdgeInsets.all(SpacingTokens.xxs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return SizedBox(
            height: optical ? 38 : 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  left: width * safeIndex,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: LiquidGlassLensDecoration(optical: optical),
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
