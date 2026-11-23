import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SoftStyle { accent, surface, outline, clear }

class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = SoftStyle.surface,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SoftStyle style;
  final bool selected;

  @override
  Widget build(BuildContext context) => SoftAction(
    onPressed: onPressed,
    style: style,
    selected: selected,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19),
            const SizedBox(width: SpacingTokens.xs),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}

class IconCapsuleButton extends StatelessWidget {
  const IconCapsuleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.style = SoftStyle.surface,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final SoftStyle style;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: SoftAction(
      label: label,
      selected: selected,
      style: style,
      onPressed: onPressed,
      child: Icon(icon, size: 23),
    ),
  );
}

class SoftAction extends StatefulWidget {
  const SoftAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.label,
    this.selected = false,
    this.style = SoftStyle.surface,
    this.radius = RadiusTokens.pill,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? label;
  final bool selected;
  final SoftStyle style;
  final BorderRadius radius;

  @override
  State<SoftAction> createState() => _SoftActionState();
}

class _SoftActionState extends State<SoftAction> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final pressed = enabled && _pressed;
    final selected = widget.selected;
    final accent = widget.style == SoftStyle.accent;
    final clear = widget.style == SoftStyle.clear;
    final outline = widget.style == SoftStyle.outline;
    final foreground = !enabled
        ? ColorTokens.muted.withValues(alpha: .55)
        : accent
        ? ColorTokens.background
        : selected
        ? ColorTokens.accent
        : ColorTokens.text;
    final fill = !enabled
        ? ColorTokens.surface.withValues(alpha: .7)
        : accent
        ? ColorTokens.accent
        : selected
        ? ColorTokens.elevated
        : clear
        ? Colors.transparent
        : outline
        ? ColorTokens.background.withValues(alpha: .32)
        : ColorTokens.elevated;
    final background = Color.alphaBlend(
      pressed
          ? ColorTokens.highlight
          : _hovered && enabled
          ? Colors.white.withValues(alpha: .07)
          : Colors.transparent,
      fill,
    );
    final border = enabled && _focused
        ? ColorTokens.accent
        : clear && !selected
        ? Colors.transparent
        : selected || outline
        ? ColorTokens.accent.withValues(alpha: .42)
        : ColorTokens.border;
    final shadows = !enabled || clear || outline
        ? const <BoxShadow>[]
        : pressed
        ? ShadowTokens.pressed
        : ShadowTokens.soft;
    final duration = MotionTokens.resolve(context, MotionTokens.press);
    return Semantics(
      label: widget.label,
      button: true,
      enabled: enabled,
      selected: selected ? true : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => _press(true) : null,
          onTapUp: enabled ? (_) => _press(false) : null,
          onTapCancel: enabled ? () => _press(false) : null,
          child: AnimatedScale(
            scale: pressed ? MotionTokens.pressedScale : 1,
            duration: duration,
            curve: MotionTokens.curve,
            child: AnimatedContainer(
              duration: duration,
              curve: MotionTokens.curve,
              constraints: const BoxConstraints(
                minHeight: SpacingTokens.tap,
                minWidth: SpacingTokens.tap,
              ),
              decoration: BoxDecoration(
                borderRadius: widget.radius,
                color: background,
                gradient:
                    !pressed && enabled && (accent || (!clear && !outline))
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.alphaBlend(
                            Colors.white.withValues(alpha: .10),
                            background,
                          ),
                          background,
                        ],
                      )
                    : null,
                border: Border.all(color: border),
                boxShadow: shadows,
              ),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.labelLarge!
                        .copyWith(color: foreground),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: RadiusTokens.panel,
      boxShadow: ShadowTokens.floating,
    ),
    child: ClipRRect(
      borderRadius: RadiusTokens.panel,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: RadiusTokens.panel,
            border: Border.all(color: ColorTokens.border),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ColorTokens.glass, Color(0xF01A2938)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.xxs),
            child: Row(
              children: List.generate(_items.length, (i) {
                final (regular, active, label) = _items[i];
                final selected = i == index;
                return Expanded(
                  child: SoftAction(
                    key: ValueKey('nav-$i'),
                    selected: selected,
                    style: SoftStyle.clear,
                    radius: RadiusTokens.card,
                    onPressed: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SpacingTokens.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? active : regular,
                            size: 23,
                            color: selected
                                ? ColorTokens.accent
                                : ColorTokens.muted,
                          ),
                          const SizedBox(height: SpacingTokens.xxs),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelMedium!
                                .copyWith(
                                  color: selected
                                      ? ColorTokens.accent
                                      : ColorTokens.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ),
  );
}
