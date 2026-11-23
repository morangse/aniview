import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/secure_vault.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../../media/sources/catalog_source.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/source_adapters.dart';
import '../../media/sources/source_models.dart';
import 'built_in_subscriptions.dart';
import 'catalog_subscription_import.dart';

class SourceManagementScreen extends ConsumerWidget {
  const SourceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceConfigsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('片源管理')),
      body: PageColumn(
        children: [
          SoftButton(
            label: '添加片源',
            icon: Icons.add_rounded,
            style: SoftStyle.accent,
            onPressed: () => _edit(context),
          ),
          const SizedBox(height: SpacingTokens.md),
          const CatalogSubscriptionImportButton(),
          const SizedBox(height: SpacingTokens.sm),
          ...sources.when(
            loading: () => const [LinearProgressIndicator()],
            error: (_, _) => const [
              StatusPanel(icon: Icons.error_outline, title: '无法读取片源配置'),
            ],
            data: (items) => [
              for (final source in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                  child: _SourceRow(source: source),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          const BuiltInSubscriptions(),
        ],
      ),
    );
  }

  static Future<void> _edit(BuildContext context, [ConfiguredSource? source]) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        sheetAnimationStyle: MotionTokens.sheetStyle(context),
        builder: (_) => SourceEditor(source: source),
      );
}

class _SourceRow extends ConsumerStatefulWidget {
  const _SourceRow({required this.source});
  final ConfiguredSource source;

  @override
  ConsumerState<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends ConsumerState<_SourceRow> {
  bool _busy = false;
  String? _status;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => _status = result);
    } on SourceIssue catch (error) {
      if (mounted) {
        setState(() => _status = '${error.state.label} · ${error.label}');
      }
    } on Exception {
      if (mounted) setState(() => _status = '片源操作暂时失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除片源？'),
        content: const Text('删除连接配置和保存在设备上的凭据。既有观看记录仍可在历史中查看。'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _run(() async {
        await ref.read(sourceStoreProvider).delete(widget.source.id);
        return null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.source;
    final builtIn = item.id == 'local' || item.id == 'legacy-direct';
    return Panel(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text(
                '${_kindLabel(item.kind)} · ${item.enabled ? '已启用' : '已停用'}',
              ),
              value: item.enabled,
              onChanged: _busy
                  ? null
                  : (value) => _run(() async {
                      await ref
                          .read(sourceStoreProvider)
                          .put(item.copyWith(enabled: value));
                      return null;
                    }),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_status != null) Text(_status!),
            if (!builtIn)
              Wrap(
                spacing: SpacingTokens.xs,
                children: [
                  if (!SourceKind.values.byName(item.kind).isImportedRule)
                    SoftButton(
                      label: '修改',
                      style: SoftStyle.clear,
                      onPressed: _busy
                          ? null
                          : () => SourceManagementScreen._edit(context, item),
                    ),
                  SoftButton(
                    label: '连接测试',
                    style: SoftStyle.outline,
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final registry = ref.read(sourceRegistryProvider);
                            final state = await SourceHealthChecker(
                              registry.http,
                              registry.store,
                            ).test(item, registry.adapter(item));
                            return '${state.label} · 连接或媒体格式检查已通过';
                          }),
                  ),
                  SoftButton(
                    label: '删除',
                    style: SoftStyle.clear,
                    onPressed: _busy ? null : _delete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(String name) => switch (name) {
  'local' => 'Android 本地文件',
  'direct' => '自有直链',
  'jsonFeed' => 'JSON 资源目录',
  'rssFeed' => 'RSS 资源目录',
  'animekoRss' => 'Animeko RSS',
  'animekoWeb' => 'Animeko 网页',
  'animekoJson' => 'Animeko JSON API',
  'webFeed' => 'Web 视频目录',
  'emby' => 'Emby',
  'jellyfin' => 'Jellyfin',
  _ => '未知类型',
};

class SourceEditor extends ConsumerStatefulWidget {
  const SourceEditor({super.key, this.source});
  final ConfiguredSource? source;

  @override
  ConsumerState<SourceEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<SourceEditor> {
  late SourceKind _kind = SourceKind.values.byName(
    widget.source?.kind ?? 'direct',
  );
  late bool _download = widget.source?.offlineAllowed ?? false;
  late bool _authorizedCatalog = _kind.isCatalog && widget.source != null;
  bool _clearCatalogHeaders = false;
  late final _name = TextEditingController(text: widget.source?.name);
  late final _url = TextEditingController(
    text: _kind == SourceKind.direct ? '' : widget.source?.endpoint,
  );
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _headers = TextEditingController();
  late final _priority = TextEditingController(
    text: '${widget.source?.priority ?? 0}',
  );
  late final _subject = TextEditingController(
    text: widget.source?.subjectId?.toString(),
  );
  late final _episode = TextEditingController(
    text: widget.source?.episodeId?.toString(),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _url,
      _user,
      _password,
      _headers,
      _priority,
      _subject,
      _episode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final previous = widget.source;
      final store = ref.read(sourceStoreProvider);
      final registry = ref.read(sourceRegistryProvider);
      final id = previous?.id ?? randomIdentifier(16);
      final name = _name.text.trim();
      final priority = int.tryParse(_priority.text.trim());
      final subject = int.tryParse(_subject.text.trim());
      final episode = int.tryParse(_episode.text.trim());
      if (name.isEmpty ||
          priority == null ||
          priority < -10 ||
          priority > 10 ||
          (_subject.text.isNotEmpty && (subject == null || subject < 1)) ||
          (_episode.text.isNotEmpty &&
              (episode == null || episode < 1 || subject == null))) {
        throw const FormatException('请检查名称、优先级、条目 ID 和剧集 ID。');
      }
      if (_kind == SourceKind.direct) {
        final secret = previous == null ? null : await store.credentials(id);
        final raw = _url.text.trim();
        final storedAddress = secret?['url'] as String?;
        final uri = parsePlaybackUrl(raw.isEmpty ? (storedAddress ?? '') : raw);
        final typedHeaders = _headers.text.isEmpty && raw.isEmpty
            ? Map<String, String>.from(secret?['headers'] as Map? ?? const {})
            : parseMediaHeaders(_headers.text);
        if (typedHeaders.isNotEmpty || uri.hasQuery && !uri.isScheme('https')) {
          serverEndpoint(uri.origin);
        }
        await store.put(
          ConfiguredSource(
            id: id,
            name: name,
            kind: 'direct',
            endpoint: uri.origin,
            userId: '',
            enabled: previous?.enabled ?? true,
            priority: priority,
            offlineAllowed: _download,
            subjectTitle: previous?.subjectId == subject
                ? previous?.subjectTitle ?? ''
                : '',
            subjectId: subject,
            episodeId: episode,
          ),
          secret: {'url': uri.toString(), 'headers': typedHeaders},
        );
      } else if (_kind.isCatalog) {
        if (!_authorizedCatalog) {
          throw const FormatException('请确认你有权使用这个媒体目录。');
        }
        final endpoint = parseCatalogEndpoint(_url.text).toString();
        final previousSecret =
            previous?.endpoint == endpoint && !_clearCatalogHeaders
            ? await store.credentials(id)
            : null;
        final typedHeaders = _headers.text.trim().isNotEmpty
            ? parseMediaHeaders(_headers.text)
            : Map<String, String>.from(
                previousSecret?['headers'] as Map? ?? const {},
              );
        await store.put(
          ConfiguredSource(
            id: id,
            name: name,
            kind: _kind.name,
            endpoint: endpoint,
            userId: '',
            enabled: previous?.enabled ?? true,
            priority: priority,
            offlineAllowed: false,
            subjectTitle: '',
          ),
          secret: {'headers': typedHeaders},
        );
      } else {
        final endpoint = serverEndpoint(_url.text);
        final address = _kind == SourceKind.emby && endpoint.path.isEmpty
            ? endpoint.replace(path: '/emby')
            : endpoint;
        var config = ConfiguredSource(
          id: id,
          name: name,
          kind: _kind.name,
          endpoint: address.toString(),
          userId: '',
          enabled: previous?.enabled ?? true,
          priority: priority,
          offlineAllowed: false,
          subjectTitle: '',
        );
        if (_user.text.trim().isEmpty &&
            previous?.endpoint == config.endpoint &&
            previous!.userId.isNotEmpty) {
          await store.put(config.copyWith(userId: previous.userId));
        } else {
          if (_user.text.trim().isEmpty) {
            throw const FormatException('请填写服务器账号。');
          }
          final adapter = registry.adapter(config) as JellyfinSource;
          final credentials = await adapter.login(
            _user.text.trim(),
            _password.text,
          );
          config = config.copyWith(userId: credentials.userId);
          await store.put(config, secret: {'token': credentials.token});
        }
      }
      if (mounted) context.pop();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SourceIssue catch (error) {
      if (mounted) setState(() => _error = error.label);
    } on Exception {
      if (mounted) setState(() => _error = '无法保存片源，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            SectionHeading(widget.source == null ? '添加片源' : '修改片源'),
            const SizedBox(height: SpacingTokens.sm),
            DropdownButtonFormField<SourceKind>(
              initialValue: _kind,
              items: [
                for (final kind in [
                  SourceKind.direct,
                  SourceKind.jellyfin,
                  SourceKind.emby,
                  SourceKind.jsonFeed,
                  SourceKind.rssFeed,
                  SourceKind.webFeed,
                ])
                  DropdownMenuItem(
                    value: kind,
                    child: Text(_kindLabel(kind.name)),
                  ),
              ],
              onChanged: widget.source != null || _busy
                  ? null
                  : (value) => setState(() {
                      _kind = value!;
                      _authorizedCatalog = false;
                    }),
              decoration: const InputDecoration(labelText: '来源类型'),
            ),
            const SizedBox(height: SpacingTokens.sm),
            _field(_name, '名称'),
            _field(
              _url,
              _kind == SourceKind.direct
                  ? (widget.source == null ? 'HTTP(S) 视频地址' : '新地址（留空保留）')
                  : _kind.isCatalog
                  ? '目录地址'
                  : '服务器根地址',
              obscure: _kind == SourceKind.direct,
              onChanged: _kind.isCatalog
                  ? (_) => setState(() => _authorizedCatalog = false)
                  : null,
            ),
            if (_kind == SourceKind.direct) ...[
              _field(_headers, '请求头（可选，每行一个“名称: 值”）', lines: 2),
              _field(_subject, 'Bangumi 条目 ID（可选）', numeric: true),
              _field(_episode, 'Bangumi 剧集 ID（可选）', numeric: true),
              SwitchListTile(
                title: const Text('我有权在设备上保存此视频'),
                subtitle: const Text('允许对支持的 MP4 创建离线下载'),
                value: _download,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _download = value),
              ),
            ] else if (_kind.isCatalog) ...[
              _field(_headers, '授权请求头（可选，每行一个“名称: 值”）', lines: 2),
              if (widget.source != null)
                CheckboxListTile(
                  title: const Text('清除已保存的请求头'),
                  value: _clearCatalogHeaders,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _clearCatalogHeaders = value!),
                ),
              CheckboxListTile(
                title: const Text('我有权通过此目录播放媒体'),
                value: _authorizedCatalog,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _authorizedCatalog = value!),
              ),
            ] else ...[
              _field(_user, '账号'),
              _field(_password, '密码', obscure: true),
            ],
            _field(_priority, '选源优先级（−10 至 10）', numeric: true),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: ColorTokens.accent)),
            const SizedBox(height: SpacingTokens.sm),
            SoftButton(
              label: _busy ? '正在保存…' : '保存片源',
              style: SoftStyle.accent,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool numeric = false,
    int lines = 1,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: obscure,
      maxLines: lines,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(signed: true)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
