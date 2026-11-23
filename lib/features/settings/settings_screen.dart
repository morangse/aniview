import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/overlays/danmaku_client.dart';
import '../player/source_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('我的')),
    body: PageColumn(
      inShell: true,
      children: [
        const Panel(
          radius: RadiusTokens.panel,
          child: ListTile(
            contentPadding: EdgeInsets.all(SpacingTokens.md),
            leading: CircleAvatar(
              backgroundColor: ColorTokens.elevated,
              child: Icon(
                Icons.person_outline_rounded,
                color: ColorTokens.accent,
              ),
            ),
            title: Text('本地个人资料'),
            subtitle: Text('收藏和观看记录保存在此设备'),
          ),
        ),
        const SizedBox(height: SpacingTokens.lg),
        Panel(
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.video_library_outlined,
                title: '打开视频',
                onTap: () => showSources(context),
              ),
              _SettingRow(
                icon: Icons.history_rounded,
                title: '播放历史',
                onTap: () => context.push('/history'),
              ),
              _SettingRow(
                icon: Icons.link_rounded,
                title: '片源管理',
                onTap: () => context.push('/sources'),
              ),
              _SettingRow(
                icon: Icons.download_outlined,
                title: '离线下载',
                onTap: () => context.push('/downloads'),
              ),
              _SettingRow(
                icon: Icons.settings_outlined,
                title: '设置',
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Panel(
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.link_rounded,
                title: 'Bangumi 账号',
                subtitle: '授权与手动同步',
                onTap: () => context.push('/account'),
              ),
              _SettingRow(
                icon: Icons.info_outline_rounded,
                title: '关于 AniView',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backingUp = false;

  Future<void> _exportBackup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final payload = await ref.read(backupServiceProvider).exportJson();
      final now = DateTime.now();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final saved = await const AndroidMediaAccess().exportBackup(
        'aniview-backup-$date.json',
        payload,
      );
      if (mounted && saved) inform(context, '本地备份已保存。');
    } on Exception {
      if (mounted) inform(context, '导出备份失败，请检查存储权限。');
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _importBackup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final raw = await const AndroidMediaAccess().pickBackup();
      if (raw == null || !mounted) return;
      final report = await ref.read(backupServiceProvider).importJson(raw);
      ref.invalidate(favoriteEntriesProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(historyProvider);
      ref.invalidate(autoplayProvider);
      ref.invalidate(autoNextProvider);
      ref.invalidate(danmakuEndpointProvider);
      ref.invalidate(danmakuEndpointsProvider);
      ref.invalidate(sourceConfigsProvider);
      if (mounted) {
        inform(
          context,
          '已恢复 ${report.favorites} 部追番、${report.watchSessions} 条观看进度与 ${report.sources} 个片源。',
        );
      }
    } on FormatException catch (error) {
      if (mounted) inform(context, error.message);
    } on Exception {
      if (mounted) inform(context, '读取或恢复备份失败。');
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _addDanmakuEndpoint() async {
    final result = await showDialog<({String? value})>(
      context: context,
      builder: (_) => const _DanmakuEndpointDialog(current: null),
    );
    final value = result?.value;
    if (value == null || value.isEmpty) return;
    await ref.read(libraryProvider).addDanmakuEndpoint(value);
  }

  @override
  Widget build(BuildContext context) {
    final autoplay = ref.watch(autoplayProvider);
    final autoNext = ref.watch(autoNextProvider);
    final danmakuEndpoint = ref.watch(danmakuEndpointProvider);
    final danmakuEndpoints =
        ref.watch(danmakuEndpointsProvider).value ?? const <String>[];
    final activeEndpoint =
        danmakuEndpoint.value ?? danmakuEndpoints.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: PageColumn(
        children: [
          const SectionHeading('播放'),
          const SizedBox(height: SpacingTokens.xs),
          Panel(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('打开视频后自动播放'),
                  value: autoplay.value ?? true,
                  onChanged: !autoplay.hasValue
                      ? null
                      : (value) async {
                          try {
                            await ref.read(libraryProvider).setAutoplay(value);
                          } on Exception {
                            if (context.mounted) {
                              inform(context, '设置未保存，请重试。');
                            }
                          }
                        },
                ),
                SwitchListTile(
                  title: const Text('播完自动连播下一集'),
                  value: autoNext.value ?? true,
                  onChanged: !autoNext.hasValue
                      ? null
                      : (value) async {
                          try {
                            await ref.read(libraryProvider).setAutoNext(value);
                          } on Exception {
                            if (context.mounted) {
                              inform(context, '设置未保存，请重试。');
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          if (autoplay.hasError)
            StatusPanel(
              icon: Icons.error_outline_rounded,
              title: '无法读取设置',
              action: '重试',
              onAction: () => ref.invalidate(autoplayProvider),
            ),
          const SizedBox(height: SpacingTokens.lg),
          const SectionHeading('弹幕'),
          const SizedBox(height: SpacingTokens.xs),
          Panel(
            child: Column(
              children: [
                if (danmakuEndpoints.isEmpty)
                  _SettingRow(
                    icon: Icons.subtitles_outlined,
                    title: '弹幕服务器地址',
                    subtitle: '未配置（可添加兼容弹弹play协议的地址，如 https://...）',
                    onTap: _addDanmakuEndpoint,
                  )
                else ...[
                  for (final endpoint in danmakuEndpoints)
                    ListTile(
                      leading: Icon(
                        endpoint == activeEndpoint
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: endpoint == activeEndpoint
                            ? ColorTokens.accent
                            : null,
                      ),
                      title: Text(
                        endpoint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        endpoint == activeEndpoint ? '当前默认' : '点击设为当前',
                      ),
                      trailing: IconButton(
                        tooltip: '删除弹幕服务器',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => ref
                            .read(libraryProvider)
                            .removeDanmakuEndpoint(endpoint),
                      ),
                      onTap: () => ref
                          .read(libraryProvider)
                          .selectDanmakuEndpoint(endpoint),
                    ),
                  _SettingRow(
                    icon: Icons.add_circle_outline_rounded,
                    title: '添加弹幕服务器',
                    subtitle: '保存多个兼容弹弹play协议的地址，随时切换',
                    onTap: _addDanmakuEndpoint,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          const SectionHeading('外观'),
          const SizedBox(height: SpacingTokens.xs),
          const Panel(
            child: ListTile(
              leading: Icon(
                Icons.dark_mode_outlined,
                color: ColorTokens.accent,
              ),
              title: Text('Midnight Mist'),
              subtitle: Text('跟随系统的减少动态效果设置'),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          const SectionHeading('数据与备份'),
          const SizedBox(height: SpacingTokens.xs),
          if (_backingUp)
            const Padding(
              padding: EdgeInsets.only(bottom: SpacingTokens.xs),
              child: LinearProgressIndicator(),
            ),
          Panel(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.upload_file_outlined,
                  title: '导出本地备份',
                  subtitle: '导出追番状态、观看进度、片源配置与字幕弹幕（不含账号密钥）',
                  onTap: _backingUp ? () {} : _exportBackup,
                ),
                _SettingRow(
                  icon: Icons.restore_outlined,
                  title: '从备份文件恢复',
                  subtitle: '合并本地数据并保留较新的观看进度',
                  onTap: _backingUp ? () {} : _importBackup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关于 AniView')),
    body: PageColumn(
      children: [
        Text('AniView', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: SpacingTokens.xs),
        const Text('0.2.5 · Android'),
        const SizedBox(height: SpacingTokens.lg),
        const Panel(
          child: Padding(
            padding: EdgeInsets.all(SpacingTokens.md),
            child: Text('番剧、剧集资料和评分来自 Bangumi。视频从你选择的文件或地址播放。'),
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            label: '开放源代码许可',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'AniView',
              applicationVersion: '0.2.5',
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: ColorTokens.accent),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _DanmakuEndpointDialog extends StatefulWidget {
  const _DanmakuEndpointDialog({required this.current});
  final String? current;

  @override
  State<_DanmakuEndpointDialog> createState() => _DanmakuEndpointDialogState();
}

class _DanmakuEndpointDialogState extends State<_DanmakuEndpointDialog> {
  late final _ctrl = TextEditingController(text: widget.current ?? '');
  String? _errorText;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorText = '请输入兼容弹弹play协议的基础地址。');
      return;
    }
    try {
      final normalized = DanmakuClient.normalizeEndpoint(raw).toString();
      Navigator.of(context).pop((value: normalized));
    } on FormatException catch (e) {
      setState(() => _errorText = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('弹幕服务器地址'),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: '兼容弹弹play协议的基础地址',
        hintText: 'https://example.com',
        errorText: _errorText,
        errorMaxLines: 2,
      ),
    ),
    actions: [
      if (widget.current != null)
        TextButton(
          onPressed: () => Navigator.of(context).pop((value: null)),
          child: const Text('清除'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: _save,
        child: const Text('保存'),
      ),
    ],
  );
}
