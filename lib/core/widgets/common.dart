import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'soft_controls.dart';

class PageColumn extends StatelessWidget {
  const PageColumn({
    super.key,
    required this.children,
    this.inShell = false,
    this.controller,
  });

  final List<Widget> children;
  final bool inShell;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final reserveNav = inShell && !AdaptiveLayout.useSideRail(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AdaptiveLayout.contentMaxWidth(context),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.md,
            SpacingTokens.sm,
            SpacingTokens.md,
            (reserveNav ? LayoutTokens.navReserve : SpacingTokens.lg) +
                MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null)
        SoftAction(
          style: SoftStyle.clear,
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action!, style: const TextStyle(color: ColorTokens.accent)),
              const Icon(
                Icons.chevron_right_rounded,
                color: ColorTokens.accent,
                size: 18,
              ),
            ],
          ),
        ),
    ],
  );
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Panel(
    child: Padding(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: ColorTokens.accent),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (message != null) ...[
                  const SizedBox(height: SpacingTokens.xxs),
                  Text(message!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (action != null) ...[
                  const SizedBox(height: SpacingTokens.xs),
                  SoftButton(
                    label: action!,
                    onPressed: onAction,
                    style: SoftStyle.outline,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.radius = RadiusTokens.card,
  });
  final Widget child;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => Material(
    color: ColorTokens.surface.withValues(alpha: 0.92),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: radius,
      side: const BorderSide(color: ColorTokens.glassBorder, width: 0.8),
    ),
    child: child,
  );
}

void inform(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
