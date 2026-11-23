import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/bangumi_http.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../data/bangumi/bangumi_sync.dart';
import '../../media/android_media_access.dart';

final bangumiSyncProvider = Provider<BangumiSyncService>((ref) {
  final upstream = BangumiHttp.createClient();
  final broker = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  ref.onDispose(() {
    upstream.close(force: true);
    broker.close(force: true);
  });
  const raw = String.fromEnvironment('ANIVIEW_BANGUMI_OAUTH_URL');
  return BangumiSyncService(
    ref.watch(libraryProvider),
    ref.watch(vaultProvider),
    BangumiSyncApi(upstream),
    BangumiOAuthBridge(broker, raw.isEmpty ? null : Uri.tryParse(raw)),
  );
});
final _account = FutureProvider<BangumiAccount?>(
  (ref) => ref.watch(bangumiSyncProvider).account(),
);

class BangumiAccountScreen extends ConsumerStatefulWidget {
  const BangumiAccountScreen({super.key});

  @override
  ConsumerState<BangumiAccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<BangumiAccountScreen> {
  final _token = TextEditingController();
  OAuthPairing? _pending;
  bool _busy = false;
  bool _pushFavorites = false;
  bool _pushWatched = false;
  String? _message;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() command) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await command();
      if (mounted) {
        setState(() => _message = result);
        ref.invalidate(_account);
      }
    } on CatalogFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } on Exception {
      if (mounted) setState(() => _message = '操作未完成。本地收藏和观看记录仍可使用。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(bangumiSyncProvider);
    final state = ref.watch(_account);
    final account = state.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi 账号')),
      body: PageColumn(
        children: [
          if (_busy || state.isLoading) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
              child: Text(
                _message!,
                style: const TextStyle(color: ColorTokens.accent),
              ),
            ),
          if (account == null && !state.isLoading) ...[
            const StatusPanel(
              icon: Icons.link_outlined,
              title: '尚未绑定 Bangumi',
              message: '绑定后可手动导入收藏，并选择是否上传本地状态。',
            ),
            const SizedBox(height: SpacingTokens.md),
            if (sync.oauth.configured) ...[
              SoftButton(
                label: _pending == null ? '在浏览器授权' : '重新开始浏览器授权',
                style: SoftStyle.accent,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final pending = await sync.oauth.begin();
                        if (!mounted) return null;
                        setState(() => _pending = pending);
                        await const AndroidMediaAccess().openBangumi(
                          pending.authorizationUrl,
                        );
                        return '在 Bangumi 完成授权后，返回 AniView 确认。';
                      }),
              ),
              if (_pending != null)
                SoftButton(
                  label: '完成授权',
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final result = await sync.complete(_pending!);
                          if (result == null) return '正在等待浏览器授权。';
                          if (mounted) setState(() => _pending = null);
                          return '已绑定 ${result.name}';
                        }),
                ),
            ] else
              const Text('此构建尚未配置 OAuth 服务。可使用 Bangumi 官方个人访问令牌绑定。'),
            const SizedBox(height: SpacingTokens.md),
            SoftButton(
              label: '打开 Bangumi 令牌页面',
              style: SoftStyle.outline,
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await const AndroidMediaAccess().openBangumi(
                        Uri.parse('https://next.bgm.tv/demo/access-token'),
                      );
                      return null;
                    }),
            ),
            const SizedBox(height: SpacingTokens.sm),
            TextField(
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '个人访问令牌'),
            ),
            const SizedBox(height: SpacingTokens.sm),
            SoftButton(
              label: '验证并绑定',
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final result = await sync.bindPersonalToken(_token.text);
                      if (mounted) _token.clear();
                      return '已绑定 ${result.name}';
                    }),
            ),
          ],
          if (account != null) ...[
            StatusPanel(
              icon: Icons.person_outline,
              title: account.name,
              message: '@${account.username}',
            ),
            const SizedBox(height: SpacingTokens.md),
            Panel(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('上传本地追番与收藏状态'),
                    subtitle: const Text('冲突时以本地修改优先，按想看/在看/看过/搁置/抛弃同步。'),
                    value: _pushFavorites,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _pushFavorites = value),
                  ),
                  SwitchListTile(
                    title: const Text('同步已看完的剧集'),
                    subtitle: const Text('仅同步有 Bangumi 剧集 ID 的完成状态。'),
                    value: _pushWatched,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _pushWatched = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            SoftButton(
              label: '手动同步',
              style: SoftStyle.accent,
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => sync.sync(
                        pushFavorites: _pushFavorites,
                        pushWatched: _pushWatched,
                      ),
                    ),
            ),
            const SizedBox(height: SpacingTokens.xs),
            SoftButton(
              label: '解绑此设备',
              style: SoftStyle.outline,
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await sync.unlink();
                      return '设备上的授权已移除。';
                    }),
            ),
          ],
        ],
      ),
    );
  }
}
