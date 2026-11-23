import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../library/collection_sheet.dart';
import '../player/source_sheet.dart';
import 'anime.dart';

class AnimeScreen extends ConsumerStatefulWidget {
  const AnimeScreen({super.key, required this.id, this.preview});

  final int id;
  final Anime? preview;

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen> {
  bool _showFullSummary = false;
  int _visibleEpisodes = 24;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final detail = ref.watch(subjectProvider(id));
    final favorites = ref.watch(favoriteEntriesProvider);
    final savedEntry = favorites.value
        ?.where((entry) => entry.anime.id == id)
        .firstOrNull;
    final anime = detail.value?.value ?? savedEntry?.anime ?? widget.preview;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('番剧详情'),
        actions: [
          if (anime != null)
            IconCapsuleButton(
              icon: Icons.video_library_outlined,
              label: '片源',
              style: SoftStyle.clear,
              onPressed: () =>
                  showSources(context, request: MediaRequest(anime: anime)),
            ),
          const SizedBox(width: SpacingTokens.xs),
        ],
      ),
      body: anime == null
          ? PageColumn(
              children: [
                if (detail.hasError)
                  StatusPanel(
                    icon: Icons.cloud_off_outlined,
                    title: '番剧详情暂不可用',
                    message: '${detail.error}',
                    action: '重试',
                    onAction: () => ref.invalidate(subjectProvider(id)),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
              ],
            )
          : _body(
              context,
              anime,
              detail,
              savedEntry,
              favorites.hasValue,
              type,
            ),
    );
  }

  Widget _body(
    BuildContext context,
    Anime anime,
    AsyncValue<CatalogValue<Anime>> detail,
    FavoriteEntry? savedEntry,
    bool favoritesReady,
    TextTheme type,
  ) {
    final episodes = ref.watch(episodesProvider(anime.id));
    final progress = ref
        .watch(historyProvider)
        .value
        ?.where(
          (entry) =>
              entry.media.subjectId == anime.id && !entry.progress.completed,
        )
        .firstOrNull;
    final episodeList = episodes.value?.value;
    final count = anime.episodeCount;
    final wide = AdaptiveLayout.useSideRail(context);

    final heroWidgets = <Widget>[
      _DetailArtwork(anime: anime),
      const SizedBox(height: SpacingTokens.md),
      Text(anime.title, style: type.headlineSmall),
      if (anime.originalName.isNotEmpty && anime.originalName != anime.title)
        Padding(
          padding: const EdgeInsets.only(top: SpacingTokens.xxs),
          child: Text(
            anime.originalName,
            style: type.bodyMedium?.copyWith(color: ColorTokens.muted),
          ),
        ),
      const SizedBox(height: SpacingTokens.xs),
      Wrap(
        spacing: SpacingTokens.sm,
        runSpacing: SpacingTokens.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Bangumi 评分  ${anime.score?.toStringAsFixed(1) ?? '暂无'}',
            style: type.labelLarge?.copyWith(color: ColorTokens.accent),
          ),
          if (anime.year case final year?) Text(year, style: type.bodySmall),
          if (anime.platform.isNotEmpty)
            Text(anime.platform, style: type.bodySmall),
          if (count != null) Text('$count 集', style: type.bodySmall),
        ],
      ),
      if (detail.value?.stale == true || detail.hasError)
        Padding(
          padding: const EdgeInsets.only(top: SpacingTokens.xs),
          child: Text('当前显示已保存的资料', style: type.bodySmall),
        ),
      if (detail.hasError)
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            label: '重试加载详情',
            style: SoftStyle.clear,
            onPressed: () => ref.invalidate(subjectProvider(anime.id)),
          ),
        ),
      const SizedBox(height: SpacingTokens.md),
      Wrap(
        spacing: SpacingTokens.xs,
        runSpacing: SpacingTokens.xs,
        children: [
          SoftButton(
            label: progress == null ? '立即播放' : '继续播放',
            icon: Icons.play_arrow_rounded,
            style: SoftStyle.accent,
            onPressed: progress != null
                ? () => context.push('/player/${progress.media.id}')
                : () => playAutomatically(context, MediaRequest(anime: anime)),
          ),
          SoftButton(
            label: savedEntry == null
                ? '加入追番'
                : savedEntry.rating == null
                ? savedEntry.status.label
                : '${savedEntry.status.label} · ${savedEntry.rating} 分',
            selected: savedEntry != null,
            style: SoftStyle.outline,
            icon: savedEntry != null
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            onPressed: !favoritesReady
                ? null
                : () => showCollectionSheet(context, ref, anime, savedEntry),
          ),
        ],
      ),
      if (anime.tags.isNotEmpty) ...[
        const SizedBox(height: SpacingTokens.md),
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          children: anime.tags
              .take(8)
              .map(
                (tag) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: RadiusTokens.pill,
                    border: Border.all(color: ColorTokens.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.xs,
                      vertical: SpacingTokens.xxs,
                    ),
                    child: Text(tag, style: type.labelSmall),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ];

    final detailWidgets = <Widget>[
      const SectionHeading('简介'),
      const SizedBox(height: SpacingTokens.xs),
      Text(
        anime.summary.isEmpty ? '暂无简介' : anime.summary,
        maxLines: _showFullSummary ? null : 4,
        overflow: _showFullSummary ? null : TextOverflow.ellipsis,
        style: type.bodyMedium?.copyWith(color: ColorTokens.muted),
      ),
      if (anime.summary.length > 108)
        Align(
          alignment: Alignment.centerLeft,
          child: SoftButton(
            label: _showFullSummary ? '收起简介' : '展开简介',
            style: SoftStyle.clear,
            onPressed: () =>
                setState(() => _showFullSummary = !_showFullSummary),
          ),
        ),
      const SizedBox(height: SpacingTokens.lg),
      SectionHeading(
        '剧集',
        action: '片源',
        onAction: () =>
            showSources(context, request: MediaRequest(anime: anime)),
      ),
      const SizedBox(height: SpacingTokens.xs),
      if (episodes.hasError)
        StatusPanel(
          icon: Icons.cloud_off_outlined,
          title: '剧集资料暂不可用',
          message: '${episodes.error}',
          action: '重试',
          onAction: () => ref.invalidate(episodesProvider(anime.id)),
        )
      else if (episodeList == null)
        const LinearProgressIndicator()
      else if (episodeList.isEmpty)
        const StatusPanel(icon: Icons.video_library_outlined, title: '暂无剧集资料')
      else ...[
        if (episodes.value?.stale == true)
          Text('当前显示剧集缓存', style: type.bodySmall),
        if (wide)
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: episodeList.take(_visibleEpisodes).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 94,
              crossAxisSpacing: SpacingTokens.xs,
              mainAxisSpacing: SpacingTokens.xs,
            ),
            itemBuilder: (_, index) =>
                _buildEpisodeCard(context, anime, episodeList[index], type),
          )
        else
          for (final episode in episodeList.take(_visibleEpisodes))
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
              child: _buildEpisodeCard(context, anime, episode, type),
            ),
        if (_visibleEpisodes < episodeList.length)
          Padding(
            padding: const EdgeInsets.only(top: SpacingTokens.xs),
            child: SoftButton(
              label: '显示更多剧集',
              onPressed: () => setState(() => _visibleEpisodes += 24),
            ),
          ),
      ],
    ];

    if (wide) {
      return PageColumn(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 312,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: heroWidgets,
                ),
              ),
              const SizedBox(width: SpacingTokens.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: detailWidgets,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return PageColumn(
      children: [
        ...heroWidgets,
        const SizedBox(height: SpacingTokens.lg),
        ...detailWidgets,
      ],
    );
  }

  Widget _buildEpisodeCard(
    BuildContext context,
    Anime anime,
    Episode episode,
    TextTheme type,
  ) => Panel(
    child: ListTile(
      leading: const Icon(
        Icons.play_circle_outline_rounded,
        color: ColorTokens.accent,
      ),
      title: Text(episode.label),
      subtitle: episode.title.isEmpty
          ? null
          : Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: episode.runningTime == null
          ? null
          : Text(episode.runningTime!, style: type.bodySmall),
      onTap: () => playAutomatically(
        context,
        MediaRequest(anime: anime, episode: episode),
      ),
    ),
  );
}

class _DetailArtwork extends StatelessWidget {
  const _DetailArtwork({required this.anime});
  final Anime anime;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: RadiusTokens.hero,
    child: SizedBox(
      height: LayoutTokens.detailArtwork,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Artwork(
            uri: anime.poster ?? anime.cover,
            alignment: Alignment.topCenter,
            decodeWidth: 960,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.36, 1],
                colors: [Colors.transparent, ColorTokens.filmScrim],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: RadiusTokens.hero,
              border: Border.all(color: ColorTokens.border),
            ),
          ),
        ],
      ),
    ),
  );
}
