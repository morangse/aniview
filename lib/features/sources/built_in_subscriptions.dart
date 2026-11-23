import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/sources/source_adapters.dart';
import '../../media/sources/subscription_catalog.dart';
import 'catalog_subscription_import.dart';

class BuiltInSubscriptions extends StatelessWidget {
  const BuiltInSubscriptions({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeading('内置订阅'),
      Text('查看订阅成员并导入当前支持的片源。', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: SpacingTokens.xs),
      for (final subscription in BuiltInSubscription.values)
        Padding(
          padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
          child: SoftButton(
            label:
                'CreamyCake ${subscription.fileName} · ${subscription.category}',
            icon: Icons.rss_feed_rounded,
            style: SoftStyle.outline,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              sheetAnimationStyle: MotionTokens.sheetStyle(context),
              builder: (_) => _SubscriptionSheet(subscription: subscription),
            ),
          ),
        ),
    ],
  );
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({required this.subscription});

  final BuiltInSubscription subscription;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  late final _http = createMediaHttp();
  late List<SubscriptionMember> _members = widget.subscription.snapshot;
  CancelToken? _request;
  bool _refreshed = false;
  bool _failed = false;

  Future<void> _refresh() async {
    if (_request != null) return;
    final cancellation = CancelToken();
    setState(() {
      _request = cancellation;
      _failed = false;
    });
    try {
      final members = await SubscriptionCatalog(_http)
          .refresh(widget.subscription, cancellation);
      if (!mounted) return;
      setState(() {
        _members = members;
        _refreshed = true;
      });
    } on Exception {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    _http.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .75,
    child: SafeArea(
      top: false,
      child: PageColumn(
        children: [
          SectionHeading(widget.subscription.fileName),
          SelectableText(
            widget.subscription.uri.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text('${_members.length} 个来源 · ${_refreshed ? '本次刷新' : '内置清单'}'),
          const SizedBox(height: SpacingTokens.xs),
          SoftButton(
            label: '导入这个订阅',
            icon: Icons.add_rounded,
            style: SoftStyle.accent,
            onPressed: () => CatalogSubscriptionImportButton.open(
              context,
              address: widget.subscription.uri.toString(),
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          SoftButton(
            label: _request == null ? '刷新成员' : '正在刷新…',
            icon: Icons.refresh_rounded,
            style: SoftStyle.outline,
            onPressed: _request == null ? _refresh : null,
          ),
          if (_failed) const Text('刷新失败，正在显示已有清单。请检查网络后重试。'),
          const SizedBox(height: SpacingTokens.sm),
          for (final member in _members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(member.name),
              subtitle: Text(switch (member.factory) {
                'rss' => 'BT / RSS',
                'web-selector' => 'Web',
                'json-api' => 'JSON API',
                _ => '其他类型',
              }),
            ),
        ],
      ),
    ),
  );
}
