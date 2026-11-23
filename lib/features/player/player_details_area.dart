import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../../media/overlays/media_overlays.dart';
import '../../media/sources/release_title_parser.dart';
import '../anime/anime.dart';
import '../library/collection_sheet.dart';
import 'overlay_controls.dart';

class PlayerDetailsArea extends ConsumerStatefulWidget {
  const PlayerDetailsArea({
    super.key,
    required this.candidate,
    required this.onSwitchSource,
    required this.onOpenEpisodes,
    required this.onSelectEpisode,
    this.onOpenDanmaku,
    this.onOpenSubtitles,
  });

  final MediaCandidate candidate;
  final VoidCallback onSwitchSource;
  final VoidCallback onOpenEpisodes;
  final void Function(Anime? anime, Episode episode) onSelectEpisode;
  final VoidCallback? onOpenDanmaku;
  final VoidCallback? onOpenSubtitles;

  @override
  ConsumerState<PlayerDetailsArea> createState() => _PlayerDetailsAreaState();
}

class _PlayerDetailsAreaState extends ConsumerState<PlayerDetailsArea> {
  bool _synopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final subjectId = widget.candidate.subjectId;
    final parsed = ReleaseTitleParser.parse(widget.candidate.sourceName);
    final overlay = ref.watch(overlayProvider(widget.candidate)).value;
    final type = Theme.of(context).textTheme;

    if (subjectId == null) {
      return ListView(
        padding: const EdgeInsets.all(SpacingTokens.md),
        children: [
          Text(widget.candidate.title, style: type.titleLarge),
          const SizedBox(height: SpacingTokens.md),
          _sourcePanel(context, parsed, overlay),
        ],
      );
    }

    final detailAsync = ref.watch(subjectProvider(subjectId));
    final episodesAsync = ref.watch(episodesProvider(subjectId));
    final favorites = ref.watch(favoriteEntriesProvider);
    final savedEntry = favorites.value
        ?.where((entry) => entry.anime.id == subjectId)
        .firstOrNull;
    final anime = detailAsync.value?.value;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        anime?.title ?? widget.candidate.title,
                        style: type.titleLarge,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    SoftButton(
                      label: savedEntry == null
                          ? '加入追番'
                          : savedEntry.rating != null
                          ? '${savedEntry.status.label} · ${savedEntry.rating}分'
                          : savedEntry.status.label,
                      icon: savedEntry != null
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      selected: savedEntry != null,
                      style: SoftStyle.outline,
                      onPressed: anime == null
                          ? null
                          : () => showCollectionSheet(
                              context,
                              ref,
                              anime,
                              savedEntry,
                            ),
                    ),
                  ],
                ),
                if ((widget.candidate.episodeLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.xxs),
                  Text(
                    widget.candidate.episodeLabel!,
                    style: type.titleMedium?.copyWith(color: ColorTokens.accent),
                  ),
                ],
                const SizedBox(height: SpacingTokens.md),
                _sourcePanel(context, parsed, overlay),
                const SizedBox(height: SpacingTokens.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('选集', style: type.titleMedium),
                    TextButton(
                      onPressed: widget.onOpenEpisodes,
                      child: const Text('全部'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (episodesAsync.value?.value != null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                padding: SpacingTokens.horizontal,
                scrollDirection: Axis.horizontal,
                itemCount: episodesAsync.value!.value.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SpacingTokens.xs),
                itemBuilder: (context, index) {
                  final ep = episodesAsync.value!.value[index];
                  final isCurrent = ep.id == widget.candidate.episodeId;
                  return SoftButton(
                    label: ep.label,
                    selected: isCurrent,
                    style: isCurrent ? SoftStyle.accent : SoftStyle.outline,
                    onPressed: () {
                      if (!isCurrent) widget.onSelectEpisode(anime, ep);
                    },
                  );
                },
              ),
            ),
          ),
        if (anime != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: SpacingTokens.sm),
                  const SectionHeading('简介'),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    anime.summary.isEmpty ? '暂无简介' : anime.summary,
                    maxLines: _synopsisExpanded ? null : 3,
                    overflow: _synopsisExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: type.bodyMedium?.copyWith(color: ColorTokens.muted),
                  ),
                  if (anime.summary.length > 90)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(
                          () => _synopsisExpanded = !_synopsisExpanded,
                        ),
                        child: Text(_synopsisExpanded ? '收起简介' : '展开简介'),
                      ),
                    ),
                  if (anime.tags.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.sm),
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
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sourcePanel(
    BuildContext context,
    ParsedRelease parsed,
    OverlayBundle? overlay,
  ) {
    final danmakuLabel =
        overlay?.danmaku != null && overlay?.settings.danmakuEnabled == true
        ? '弹幕 · ${overlay!.danmaku!.items.length} 条'
        : overlay?.danmaku != null
        ? '弹幕 · 已载入'
        : '弹幕设置';
    final subLabel = overlay?.assSubtitle != null
        ? '外挂 ASS · libass'
        : overlay?.subtitle != null
        ? '外挂字幕 · 已载入'
        : '字幕与音轨';

    return Panel(
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(
                widget.candidate.sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: parsed.displayTags.isEmpty
                  ? null
                  : Text(parsed.displayTags.join(' · ')),
              trailing: const Icon(Icons.swap_horiz_rounded),
              onTap: widget.onSwitchSource,
            ),
          ),
          if (widget.onOpenDanmaku != null || widget.onOpenSubtitles != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.sm,
                0,
                SpacingTokens.sm,
                SpacingTokens.sm,
              ),
              child: Row(
                children: [
                  if (widget.onOpenDanmaku != null)
                    Expanded(
                      child: SoftButton(
                        label: danmakuLabel,
                        icon: Icons.subtitles_outlined,
                        style: SoftStyle.outline,
                        onPressed: widget.onOpenDanmaku,
                      ),
                    ),
                  if (widget.onOpenDanmaku != null &&
                      widget.onOpenSubtitles != null)
                    const SizedBox(width: SpacingTokens.xs),
                  if (widget.onOpenSubtitles != null)
                    Expanded(
                      child: SoftButton(
                        label: subLabel,
                        icon: Icons.closed_caption_outlined,
                        style: SoftStyle.outline,
                        onPressed: widget.onOpenSubtitles,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
