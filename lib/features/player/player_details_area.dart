import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../../media/overlays/media_overlays.dart';
import '../../media/playback_controller.dart';
import '../../media/sources/release_title_parser.dart';
import '../../media/sources/source_models.dart';
import '../anime/anime.dart';
import '../library/collection_sheet.dart';
import 'overlay_controls.dart';
import 'player_resolve_screen.dart';

class PlayerDetailsArea extends ConsumerStatefulWidget {
  const PlayerDetailsArea({
    super.key,
    required this.candidate,
    required this.onSwitchSource,
    required this.onOpenEpisodes,
    required this.onSelectEpisode,
    this.controller,
    this.onOpenDanmaku,
    this.onOpenSubtitles,
  });

  final MediaCandidate candidate;
  final VoidCallback onSwitchSource;
  final VoidCallback onOpenEpisodes;
  final void Function(Anime? anime, Episode episode) onSelectEpisode;
  final PlaybackController? controller;
  final VoidCallback? onOpenDanmaku;
  final VoidCallback? onOpenSubtitles;

  @override
  ConsumerState<PlayerDetailsArea> createState() => _PlayerDetailsAreaState();
}

class _PlayerDetailsAreaState extends ConsumerState<PlayerDetailsArea> {
  bool _synopsisExpanded = false;
  bool _showInlineSources = false;

  @override
  Widget build(BuildContext context) {
    final subjectId = widget.candidate.subjectId;
    final parsed = ReleaseTitleParser.parse(widget.candidate.sourceName);
    final overlay = ref.watch(overlayProvider(widget.candidate)).value;
    final type = Theme.of(context).textTheme;
    final isApple = AdaptiveLayout.isApplePlatform;

    if (subjectId == null) {
      return ListView(
        padding: const EdgeInsets.all(SpacingTokens.md),
        children: [
          Text(widget.candidate.title, style: type.titleLarge),
          const SizedBox(height: SpacingTokens.md),
          _sourcePanel(context, parsed, overlay, anime: null, episode: null),
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
    final episodeList = episodesAsync.value?.value;
    final currentEpisode = episodeList
        ?.where((ep) => ep.id == widget.candidate.episodeId)
        .firstOrNull;

    if (isApple) {
      return _buildIosDetails(
        context,
        anime: anime,
        episodes: episodeList,
        currentEpisode: currentEpisode,
        savedEntry: savedEntry,
        parsed: parsed,
        overlay: overlay,
        type: type,
      );
    }

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
                _sourcePanel(
                  context,
                  parsed,
                  overlay,
                  anime: anime,
                  episode: currentEpisode,
                ),
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
        if (episodeList != null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                padding: SpacingTokens.horizontal,
                scrollDirection: Axis.horizontal,
                itemCount: episodeList.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SpacingTokens.xs),
                itemBuilder: (context, index) {
                  final ep = episodeList[index];
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

  Widget _buildIosDetails(
    BuildContext context, {
    required Anime? anime,
    required List<Episode>? episodes,
    required Episode? currentEpisode,
    required FavoriteEntry? savedEntry,
    required ParsedRelease parsed,
    required OverlayBundle? overlay,
    required TextTheme type,
  }) {
    final heroUri = anime?.poster ?? anime?.cover ?? widget.candidate.cover;
    final historyEntries =
        ref.watch(historyProvider).value ?? const <WatchEntry>[];
    final historyByEpisode = <int, WatchEntry>{
      for (final e in historyEntries)
        if (e.media.subjectId == widget.candidate.subjectId &&
            e.media.episodeId != null)
          e.media.episodeId!: e,
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              if (heroUri != null)
                Positioned.fill(
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 24,
                            sigmaY: 24,
                          ),
                          child: Opacity(
                            opacity: 0.42,
                            child: Artwork(uri: heroUri, decodeWidth: 420),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x400A111A),
                                Color(0xEB101923),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(SpacingTokens.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime?.title ?? widget.candidate.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((widget.candidate.episodeLabel ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.candidate.episodeLabel!,
                        style: type.labelLarge?.copyWith(
                          color: const Color(0xFF6BB5FF),
                        ),
                      ),
                    ],
                    const SizedBox(height: SpacingTokens.sm),
                    Row(
                      children: [
                        LiquidGlassCircleButton(
                          icon: savedEntry != null
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: savedEntry == null
                              ? '加入追番'
                              : savedEntry.status.label,
                          active: savedEntry != null,
                          size: 40,
                          iconSize: 19,
                          onPressed: anime == null
                              ? null
                              : () => showCollectionSheet(
                                  context,
                                  ref,
                                  anime,
                                  savedEntry,
                                ),
                        ),
                        const SizedBox(width: SpacingTokens.sm),
                        LiquidGlassCircleButton(
                          icon: Icons.swap_horiz_rounded,
                          label: '切换片源',
                          active: _showInlineSources,
                          size: 40,
                          iconSize: 19,
                          onPressed: () => setState(
                            () => _showInlineSources = !_showInlineSources,
                          ),
                        ),
                        if (widget.onOpenDanmaku != null) ...[
                          const SizedBox(width: SpacingTokens.sm),
                          LiquidGlassCircleButton(
                            icon: Icons.subtitles_outlined,
                            label: '弹幕设置',
                            active: overlay?.settings.danmakuEnabled == true,
                            size: 40,
                            iconSize: 19,
                            onPressed: widget.onOpenDanmaku,
                          ),
                        ],
                        if (widget.onOpenSubtitles != null) ...[
                          const SizedBox(width: SpacingTokens.sm),
                          LiquidGlassCircleButton(
                            icon: Icons.closed_caption_outlined,
                            label: '字幕与音轨',
                            size: 40,
                            iconSize: 19,
                            onPressed: widget.onOpenSubtitles,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.md),
                    _sourcePanel(
                      context,
                      parsed,
                      overlay,
                      anime: anime,
                      episode: currentEpisode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (episodes != null && episodes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.md,
                SpacingTokens.xs,
                SpacingTokens.md,
                SpacingTokens.xs,
              ),
              child: Row(
                children: [
                  Text(
                    '选集',
                    style: type.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onOpenEpisodes,
                    child: const Text('全部'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 158,
              child: ListView.separated(
                padding: SpacingTokens.horizontal,
                scrollDirection: Axis.horizontal,
                itemCount: episodes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SpacingTokens.xs),
                itemBuilder: (_, index) {
                  final ep = episodes[index];
                  final isCurrent = ep.id == widget.candidate.episodeId;
                  final watchEntry = historyByEpisode[ep.id];
                  final code = ep.kind == EpisodeKind.regular
                      ? 'E${ep.number.toString().padLeft(2, '0')}'
                      : ep.label;
                  return SizedBox(
                    width: 176,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isCurrent) return;
                        HapticFeedback.selectionClick();
                        widget.onSelectEpisode(anime, ep);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Artwork(
                                    uri: anime?.cover ?? anime?.poster ?? widget.candidate.cover,
                                    asset: (anime?.cover ?? anime?.poster ?? widget.candidate.cover) == null
                                        ? localArtwork
                                        : null,
                                    alignment: Alignment(
                                      ((ep.number % 3) - 1) * 0.14,
                                      -0.2,
                                    ),
                                    decodeWidth: 360,
                                  ),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0x30080D14),
                                          Color(0xB8080D14),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (watchEntry != null)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: LinearProgressIndicator(
                                        minHeight: 3,
                                        value: watchEntry.progress.fraction
                                            .clamp(0.02, 1.0),
                                        backgroundColor: Colors.white24,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF6BB5FF),
                                            ),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrent
                                                ? Colors.white.withValues(
                                                    alpha: 0.78,
                                                  )
                                                : Colors.white.withValues(
                                                    alpha: 0.14,
                                                  ),
                                            width: isCurrent ? 1.5 : 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ep.title.isEmpty ? ep.label : '$code · ${ep.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelMedium?.copyWith(
                              color: isCurrent
                                  ? ColorTokens.text
                                  : Colors.white.withValues(alpha: 0.88),
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          Text(
                            ep.runningTime ?? (isCurrent ? '正在播放' : '点击播放'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (anime != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
    OverlayBundle? overlay, {
    required Anime? anime,
    required Episode? episode,
  }) {
    final isApple = AdaptiveLayout.isApplePlatform;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
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
                  trailing: Icon(
                    isApple && _showInlineSources
                        ? Icons.expand_less_rounded
                        : Icons.swap_horiz_rounded,
                  ),
                  onTap: () {
                    if (isApple) {
                      setState(() => _showInlineSources = !_showInlineSources);
                    } else {
                      widget.onSwitchSource();
                    }
                  },
                ),
              ),
              if (!isApple &&
                  (widget.onOpenDanmaku != null ||
                      widget.onOpenSubtitles != null))
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
        ),
        if (isApple && _showInlineSources) ...[
          const SizedBox(height: SpacingTokens.sm),
          InPlayerSourcePanel(
            request: MediaSearchRequest(anime: anime, episode: episode),
            resumeAt: widget.controller?.positionListenable.value,
            previousDuration: widget.controller?.durationListenable.value,
            onLaunch: (launch) async {
              await widget.controller?.pause();
              if (context.mounted) {
                context.replace(
                  '/player/${launch.candidate.id}',
                  extra: launch.session,
                );
              }
            },
          ),
        ],
      ],
    );
  }
}

