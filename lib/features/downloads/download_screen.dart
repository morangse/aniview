import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/downloads/download_manager.dart';
import '../../media/sources/source_models.dart';

final downloadManagerProvider = Provider<DownloadManager>(
  (ref) => DownloadManager(
    ref.watch(resolverProvider),
    () async => Directory(
      p.join((await getApplicationSupportDirectory()).path, 'downloads-v1'),
    ),
    const AndroidMediaAccess().availableBytes,
  ),
);
final _tasks = StreamProvider<List<DownloadTask>>(
  (ref) => ref.watch(downloadManagerProvider).watch(),
);

class DownloadScreen extends ConsumerWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(downloadManagerProvider);
    final tasks = ref.watch(_tasks);
    final sources =
        ref.watch(sourceConfigsProvider).value ?? const <ConfiguredSource>[];
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on SourceIssue catch (error) {
        if (context.mounted) inform(context, error.label);
      } on Exception {
        if (context.mounted) inform(context, '无法完成此下载操作。');
      }
    }

    Future<void> remove(String id, {required bool cancel}) async {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(cancel ? '取消下载？' : '删除离线文件？'),
          content: const Text('此任务的文件将从 AniView 私有离线目录移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('保留'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (accepted == true && context.mounted) {
        await run(() => cancel ? manager.cancel(id) : manager.remove(id));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('离线下载')),
      body: PageColumn(
        children: [
          StatusPanel(
            icon: Icons.storage_rounded,
            title: 'AniView 私有下载目录',
            message:
                '已占用 ${_size((tasks.value ?? []).fold(0, (int total, row) => total + row.received))}。'
                '在片源管理中为有权离线保存的 MP4 启用下载。',
            action: '片源管理',
            onAction: () => context.push('/sources'),
          ),
          const SizedBox(height: SpacingTokens.md),
          for (final source in sources.where(
            (item) =>
                item.enabled && item.offlineAllowed && item.kind == 'direct',
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
              child: Panel(
                child: ListTile(
                  leading: const Icon(
                    Icons.download_outlined,
                    color: ColorTokens.accent,
                  ),
                  title: Text(source.name),
                  trailing: IconCapsuleButton(
                    icon: Icons.download_rounded,
                    label: '下载 ${source.name}',
                    onPressed: () => unawaited(
                      run(() async {
                        await manager.enqueue(source.id);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          const SectionHeading('下载任务'),
          ...tasks.when(
            loading: () => const [LinearProgressIndicator()],
            error: (_, _) => const [
              StatusPanel(icon: Icons.error_outline, title: '无法读取下载任务'),
            ],
            data: (items) => [
              if (items.isEmpty)
                const StatusPanel(
                  icon: Icons.download_outlined,
                  title: '暂无离线下载',
                ),
              for (final task in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                  child: Panel(
                    child: Padding(
                      padding: const EdgeInsets.all(SpacingTokens.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${_state(task.state)} · ${_size(task.received)}'
                            '${task.total == null ? '' : ' / ${_size(task.total!)}'}',
                          ),
                          if (task.error != null) Text(task.error!),
                          const SizedBox(height: SpacingTokens.xs),
                          LinearProgressIndicator(
                            value: task.total == null || task.total == 0
                                ? (task.state == 'running' ? null : 0)
                                : (task.received / task.total!).clamp(0, 1),
                          ),
                          Wrap(
                            spacing: SpacingTokens.xs,
                            children: [
                              if (task.state == 'running')
                                SoftButton(
                                  label: '暂停',
                                  onPressed: () =>
                                      run(() => manager.pause(task.id)),
                                )
                              else if (task.state == 'complete')
                                SoftButton(
                                  label: '离线播放',
                                  style: SoftStyle.accent,
                                  onPressed: () => run(() async {
                                    final media = await manager.offlineMedia(
                                      task,
                                    );
                                    if (context.mounted) {
                                      await context.push('/player/${media.id}');
                                    }
                                  }),
                                )
                              else
                                SoftButton(
                                  label: task.state == 'failed' ? '重试' : '继续',
                                  onPressed: () => unawaited(
                                    run(() => manager.resume(task.id)),
                                  ),
                                ),
                              if (const [
                                'running',
                                'queued',
                                'paused',
                              ].contains(task.state))
                                SoftButton(
                                  label: '取消下载',
                                  style: SoftStyle.clear,
                                  onPressed: () =>
                                      remove(task.id, cancel: true),
                                ),
                              SoftButton(
                                label: '删除',
                                style: SoftStyle.clear,
                                onPressed: () => remove(task.id, cancel: false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _state(String value) => switch (value) {
  'running' => '下载中',
  'complete' => '已完成',
  'paused' => '已暂停',
  'failed' => '失败',
  'canceled' => '已取消',
  _ => '等待开始',
};

String _size(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
