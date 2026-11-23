import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../anime/anime.dart';
import '../discover/discover_screen.dart';
import '../player/source_sheet.dart';
import 'collection_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  CollectionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final favorites = ref.watch(favoriteEntriesProvider);
    final active =
        history.value
            ?.where((entry) => !entry.progress.completed)
            .take(3)
            .toList() ??
        const <WatchEntry>[];
    final lastBySubject = <int, WatchEntry>{};
    for (final entry in history.value ?? const <WatchEntry>[]) {
      if (entry.media.subjectId case final id?) {
        lastBySubject.putIfAbsent(id, () => entry);
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('追番')),
      body: PageColumn(
        inShell: true,
        children: [
          SectionHeading(
            '继续观看',
            action: '全部历史',
            onAction: () => context.push('/history'),
          ),
          const SizedBox(height: SpacingTokens.xs),
          if (history.isLoading)
            const LinearProgressIndicator()
          else if (history.hasError)
            StatusPanel(
              icon: Icons.history_rounded,
              title: '无法读取观看记录',
              action: '重试',
              onAction: () => ref.invalidate(historyProvider),
            )
          else if (active.isEmpty)
            StatusPanel(
              icon: Icons.play_circle_outline_rounded,
              title: '暂无未看完的影片',
              action: '打开视频',
              onAction: () => showSources(context),
            )
          else
            for (final entry in active) WatchRow(entry: entry),
          const SizedBox(height: SpacingTokens.lg),
          const SectionHeading('我的追番'),
          const SizedBox(height: SpacingTokens.sm),
          ...favorites.when(
            loading: () => const [LinearProgressIndicator()],
            error: (_, _) => [
              StatusPanel(
                icon: Icons.bookmark_outline_rounded,
                title: '无法读取追番列表',
                action: '重试',
                onAction: () => ref.invalidate(favoriteEntriesProvider),
              ),
            ],
            data: (items) {
              final counts = <CollectionStatus, int>{};
              for (final entry in items) {
                counts[entry.status] = (counts[entry.status] ?? 0) + 1;
              }
              final filtered = _filter == null
                  ? items
                  : items.where((entry) => entry.status == _filter).toList();
              return [
                if (items.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SoftButton(
                          label: '全部 (${items.length})',
                          selected: _filter == null,
                          style: _filter == null
                              ? SoftStyle.accent
                              : SoftStyle.outline,
                          onPressed: () => setState(() => _filter = null),
                        ),
                        for (final status in CollectionStatus.values) ...[
                          const SizedBox(width: SpacingTokens.xs),
                          SoftButton(
                            label: '${status.label} (${counts[status] ?? 0})',
                            selected: _filter == status,
                            style: _filter == status
                                ? SoftStyle.accent
                                : SoftStyle.outline,
                            onPressed: () => setState(() => _filter = status),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                ],
                if (items.isEmpty)
                  StatusPanel(
                    icon: Icons.bookmark_outline_rounded,
                    title: '还没有追番',
                    message: '在番剧详情中加入追番，之后即可从这里找回。',
                    action: '发现番剧',
                    onAction: () => context.go('/discover'),
                  )
                else if (filtered.isEmpty)
                  StatusPanel(
                    icon: Icons.filter_list_off_rounded,
                    title: '当前分类暂无条目',
                    message: '没有标记为「${_filter!.label}」的番剧。',
                  ),
                for (final entry in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                    child: AnimeResultRow(
                      anime: entry.anime,
                      subtitle: [
                        entry.status.label,
                        if (entry.rating != null) '${entry.rating} 分',
                        lastBySubject[entry.anime.id]?.description ?? '尚未观看',
                      ].join(' · '),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconCapsuleButton(
                            icon: Icons.edit_outlined,
                            label: '编辑收藏 ${entry.anime.title}',
                            style: SoftStyle.clear,
                            onPressed: () => showCollectionSheet(
                              context,
                              ref,
                              entry.anime,
                              entry,
                            ),
                          ),
                          if (lastBySubject[entry.anime.id] case final recent?)
                            IconCapsuleButton(
                              icon: Icons.play_arrow_rounded,
                              label: '继续播放 ${entry.anime.title}',
                              style: SoftStyle.clear,
                              onPressed: () =>
                                  context.push('/player/${recent.media.id}'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('播放历史')),
      body: PageColumn(
        children: history.when(
          loading: () => const [LinearProgressIndicator()],
          error: (_, _) => [
            StatusPanel(
              icon: Icons.history_rounded,
              title: '无法读取历史',
              action: '重试',
              onAction: () => ref.invalidate(historyProvider),
            ),
          ],
          data: (entries) => [
            if (entries.isEmpty)
              StatusPanel(
                icon: Icons.history_rounded,
                title: '暂无播放历史',
                action: '打开视频',
                onAction: () => showSources(context),
              ),
            for (final entry in entries) WatchRow(entry: entry, showDate: true),
          ],
        ),
      ),
    );
  }
}

extension _WatchDescription on WatchEntry {
  String get description => [
    media.episodeLabel,
    progress.completed ? '已看完' : '已观看 ${(progress.fraction * 100).round()}%',
  ].nonNulls.join(' · ');
}

class WatchRow extends StatelessWidget {
  const WatchRow({super.key, required this.entry, this.showDate = false});

  final WatchEntry entry;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatCompactDate(entry.progress.updatedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
      child: Panel(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
          ),
          minTileHeight: 78,
          leading: ClipRRect(
            borderRadius: RadiusTokens.card,
            child: SizedBox(
              width: 62,
              height: 48,
              child: Artwork(
                uri: entry.media.cover,
                asset: entry.media.subjectId == null ? localArtwork : null,
                decodeWidth: 180,
              ),
            ),
          ),
          title: Text(
            entry.media.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showDate ? '${entry.description} · $date' : entry.description,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SpacingTokens.xxs),
              LinearProgressIndicator(
                value: entry.progress.fraction,
                minHeight: 3,
                borderRadius: RadiusTokens.pill,
              ),
            ],
          ),
          trailing: const Icon(
            Icons.play_circle_outline_rounded,
            color: ColorTokens.accent,
          ),
          onTap: () => context.push('/player/${entry.media.id}'),
        ),
      ),
    );
  }
}
