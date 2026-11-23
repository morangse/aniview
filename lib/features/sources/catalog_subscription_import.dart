import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/sources/catalog_subscription.dart';
import '../../media/sources/source_models.dart';

class CatalogSubscriptionImportButton extends StatelessWidget {
  const CatalogSubscriptionImportButton({super.key});

  static Future<void> open(BuildContext context, {String? address}) async {
    final result = await showModalBottomSheet<CatalogImportResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MotionTokens.sheetStyle(context),
      builder: (_) => _CatalogSubscriptionSheet(initialAddress: address),
    );
    if (context.mounted && result != null) {
      final skipped = result.skipped == 0 ? '' : '，已有 ${result.skipped} 个';
      inform(context, '已添加 ${result.added} 个片源$skipped');
    }
  }

  @override
  Widget build(BuildContext context) => SoftButton(
    label: '导入订阅',
    icon: Icons.rss_feed_rounded,
    style: SoftStyle.outline,
    onPressed: () => open(context),
  );
}

class _CatalogSubscriptionSheet extends ConsumerStatefulWidget {
  const _CatalogSubscriptionSheet({required this.initialAddress});

  final String? initialAddress;

  @override
  ConsumerState<_CatalogSubscriptionSheet> createState() =>
      _CatalogSubscriptionSheetState();
}

class _CatalogSubscriptionSheetState
    extends ConsumerState<_CatalogSubscriptionSheet> {
  late final _address = TextEditingController(text: widget.initialAddress);
  final _selected = <String>{};
  Set<String> _existingSources = {};
  CatalogSubscription? _preview;
  CancelToken? _request;
  bool _saving = false;
  String? _error;

  bool get _busy => _request != null || _saving;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    _address.dispose();
    super.dispose();
  }

  void _clearReview() {
    _preview = null;
    _existingSources = {};
    _selected.clear();
    _error = null;
  }

  Future<void> _fetch() async {
    if (_busy) return;
    final request = CancelToken();
    setState(() {
      _clearReview();
      _request = request;
    });
    FocusScope.of(context).unfocus();
    try {
      final http = ref.read(sourceRegistryProvider).http;
      final store = ref.read(sourceStoreProvider);
      final subscription = await CatalogSubscription.read(
        http,
        _address.text,
        cancelToken: request,
      );
      if (!mounted) return;
      final existing = await store.sources();
      if (mounted) {
        setState(() {
          _preview = subscription;
          _existingSources = existing.map((source) => source.id).toSet();
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SourceIssue catch (error) {
      if (mounted) setState(() => _error = error.label);
    } on Exception {
      if (mounted) setState(() => _error = '无法读取订阅，请检查地址和网络。');
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || preview == null || _selected.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await preview.importSelected(
        ref.read(sourceStoreProvider),
        _selected,
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(result);
      }
    } on Exception {
      if (mounted) setState(() => _error = '无法保存片源，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _preview?.members;
    final addable = members?.where((entry) => entry.canImport).length ?? 0;
    final pending = members?.where(
      (entry) => entry.canImport && !_existingSources.contains(entry.sourceId),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.md,
            0,
            SpacingTokens.md,
            SpacingTokens.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading('导入订阅'),
              const SizedBox(height: SpacingTokens.sm),
              TextField(
                controller: _address,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onChanged: (_) => setState(_clearReview),
                onSubmitted: (_) => _fetch(),
                decoration: const InputDecoration(
                  labelText: '订阅地址',
                  helperText: '可预览 AniView v1 和 Animeko v2。省略协议时使用 HTTPS。',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              SoftButton(
                label: _request == null ? '预览订阅' : '正在读取…',
                style: SoftStyle.outline,
                onPressed: _busy ? null : _fetch,
              ),
              if (_error != null) ...[
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  _error!,
                  style: const TextStyle(color: ColorTokens.accent),
                ),
              ],
              if (members != null) ...[
                const SizedBox(height: SpacingTokens.md),
                if (members.isEmpty)
                  const Text('订阅清单中暂无片源。')
                else ...[
                  SectionHeading(addable == 0 ? '订阅成员' : '选择片源'),
                  Text(
                    addable == 0
                        ? '已读取 ${members.length} 个片源。当前版本暂无适配的类型。'
                        : '已读取 ${members.length} 个片源，其中 $addable 个支持导入。',
                  ),
                  if (pending?.isNotEmpty == true) ...[
                    const SizedBox(height: SpacingTokens.sm),
                    Wrap(
                      spacing: SpacingTokens.xs,
                      runSpacing: SpacingTokens.xs,
                      children: [
                        if (pending!.length > 1)
                          SoftButton(
                            label: '全选可导入',
                            style: SoftStyle.outline,
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _selected.addAll(
                                      pending.map((entry) => entry.id),
                                    ),
                                  ),
                          ),
                        SoftButton(
                          label: _saving ? '正在导入…' : '导入所选片源',
                          style: SoftStyle.accent,
                          onPressed: !_busy && _selected.isNotEmpty
                              ? _import
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.xs),
                  ],
                  for (final member in members) _memberTile(member),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberTile(CatalogSubscriptionMember member) {
    final alreadyAdded = _existingSources.contains(member.sourceId);
    final endpoint = member.endpoint;
    if (!member.canImport) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(member.name),
        subtitle: Text(member.formatLabel),
      );
    }
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: alreadyAdded || _selected.contains(member.id),
      title: Text(member.name),
      subtitle: Text(
        '${member.formatLabel}${alreadyAdded ? ' · 已添加' : ''}'
        '${endpoint == null ? '' : '\n$endpoint'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: alreadyAdded || _busy
          ? null
          : (selected) => setState(() {
              if (selected == true) {
                _selected.add(member.id);
              } else {
                _selected.remove(member.id);
              }
            }),
    );
  }
}
