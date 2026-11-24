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
import '../../media/media.dart';
import '../library/collection_sheet.dart';
import '../player/player_controls_bar.dart';
import '../player/source_sheet.dart';
import 'anime.dart';

class IosAnimeDetailView extends ConsumerStatefulWidget {
  const IosAnimeDetailView({
    super.key,
    required this.anime,
    required this.detail,
    required this.savedEntry,
    required this.favoritesReady,
  });

  final Anime anime;
  final AsyncValue<CatalogValue<Anime>> detail;
  final FavoriteEntry? savedEntry;
  final bool favoritesReady;

  @override
  ConsumerState<IosAnimeDetailView> createState() => _IosAnimeDetailViewState();
}

class _IosAnimeDetailViewState extends ConsumerState<IosAnimeDetailView> {
  final ScrollController _episodeScrollController = ScrollController();
  bool _showFullSummary = false;
  int? _selectedEpisodeId;

  @override
  void dispose() {
    _episodeScrollController.dispose();
    super.dispose();
  }

  void _scrollToEpisode(int index, double cardStride) {
    if (!_episodeScrollController.hasClients) return;
    final target = (index * cardStride).clamp(
      0.0,
      _episodeScrollController.position.maxScrollExtent,
    );
    _episodeScrollController.animateTo(
      target,
      duration: MotionTokens.resolve(
        context,
        const Duration(milliseconds: 280),
      ),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final isPad = AdaptiveLayout.isPad(context);
    final hPad = AdaptiveLayout.iosPagePadding(context);
    final episodes = ref.watch(episodesProvider(anime.id));
    final historyEntries =
        ref.watch(historyProvider).value ?? const <WatchEntry>[];

    WatchEntry? resumeEntry;
    final historyByEpisode = <int, WatchEntry>{};
    for (final entry in historyEntries) {
      if (entry.media.subjectId != anime.id) continue;
      if (entry.media.episodeId case final epId?) {
        historyByEpisode.putIfAbsent(epId, () => entry);
      }
      if (resumeEntry == null && !entry.progress.completed) {
        resumeEntry = entry;
      }
    }

    final episodeList = episodes.value?.value;
    final cardWidth = isPad ? 256.0 : 224.0;
    final cardGap = isPad ? SpacingTokens.sm : SpacingTokens.xs;
    final activeEpId =
        _selectedEpisodeId ??
        resumeEntry?.media.episodeId ??
        episodeList?.firstOrNull?.id;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _IosBlurredHero(
              anime: anime,
              detail: widget.detail,
              savedEntry: widget.savedEntry,
              favoritesReady: widget.favoritesReady,
              resumeEntry: resumeEntry,
              isPad: isPad,
              hPad: hPad,
              showFullSummary: _showFullSummary,
              onToggleSummary: () =>
                  setState(() => _showFullSummary = !_showFullSummary),
              onBack: () => context.pop(),
              onRefresh: () => ref.invalidate(subjectProvider(anime.id)),
              onOpenCollection: () => showCollectionSheet(
                context,
                ref,
                anime,
                widget.savedEntry,
              ),
              onOpenSources: () =>
                  showSources(context, request: MediaRequest(anime: anime)),
              onPlay: resumeEntry != null
                  ? () => context.push('/player/${resumeEntry!.media.id}')
                  : () =>
                        playAutomatically(context, MediaRequest(anime: anime)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, SpacingTokens.sm, hPad, 0),
              child: Row(
                children: [
                  Text(
                    '剧集',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (episodeList != null && episodeList.isNotEmpty) ...[
                    const SizedBox(width: SpacingTokens.xs),
                    Text(
                      '共 ${episodeList.length} 集',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showSources(
                      context,
                      request: MediaRequest(anime: anime),
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 17),
                    label: const Text('切换片源'),
                  ),
                ],
              ),
            ),
          ),
          if (episodes.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(hPad),
                child: StatusPanel(
                  icon: Icons.cloud_off_outlined,
                  title: '剧集资料暂不可用',
                  message: '${episodes.error}',
                  action: '重试',
                  onAction: () => ref.invalidate(episodesProvider(anime.id)),
                ),
              ),
            )
          else if (episodeList == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(hPad),
                child: const LinearProgressIndicator(),
              ),
            )
          else if (episodeList.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(hPad),
                child: const StatusPanel(
                  icon: Icons.video_library_outlined,
                  title: '暂无剧集资料',
                ),
              ),
            )
          else ...[
            if (episodes.value?.stale == true)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Text(
                    '当前显示剧集缓存',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: episodeList.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final ep = episodeList[index];
                    final selected = ep.id == activeEpId;
                    final label = ep.kind == EpisodeKind.regular
                        ? '${ep.number}'
                        : ep.label;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedEpisodeId = ep.id);
                        _scrollToEpisode(index, cardWidth + cardGap);
                      },
                      child: AnimatedContainer(
                        duration: MotionTokens.resolve(
                          context,
                          MotionTokens.transition,
                        ),
                        constraints: const BoxConstraints(minWidth: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: RadiusTokens.pill,
                          color: selected
                              ? ColorTokens.text
                              : Colors.white.withValues(alpha: 0.11),
                          border: Border.all(
                            color: selected
                                ? ColorTokens.text
                                : Colors.white.withValues(alpha: 0.14),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? ColorTokens.background
                                : Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: SpacingTokens.xs)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: isPad ? 228 : 206,
                child: ListView.separated(
                  controller: _episodeScrollController,
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  scrollDirection: Axis.horizontal,
                  itemCount: episodeList.length,
                  separatorBuilder: (_, _) => SizedBox(width: cardGap),
                  itemBuilder: (context, index) {
                    final ep = episodeList[index];
                    final watchEntry = historyByEpisode[ep.id];
                    final selected = ep.id == activeEpId;
                    return _IosEpisodeCard(
                      anime: anime,
                      episode: ep,
                      watchEntry: watchEntry,
                      width: cardWidth,
                      selected: selected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedEpisodeId = ep.id);
                        playAutomatically(
                          context,
                          MediaRequest(anime: anime, episode: ep),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
          if (anime.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  SpacingTokens.md,
                  hPad,
                  SpacingTokens.lg,
                ),
                child: Wrap(
                  spacing: SpacingTokens.xs,
                  runSpacing: SpacingTokens.xs,
                  children: anime.tags
                      .take(10)
                      .map(
                        (tag) => LiquidGlassSurface(
                          radius: RadiusTokens.pill,
                          blur: 10,
                          tint: const Color(0x52121D29),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.sm,
                            vertical: 5,
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: SpacingTokens.lg + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _IosBlurredHero extends StatelessWidget {
  const _IosBlurredHero({
    required this.anime,
    required this.detail,
    required this.savedEntry,
    required this.favoritesReady,
    required this.resumeEntry,
    required this.isPad,
    required this.hPad,
    required this.showFullSummary,
    required this.onToggleSummary,
    required this.onBack,
    required this.onRefresh,
    required this.onOpenCollection,
    required this.onOpenSources,
    required this.onPlay,
  });

  final Anime anime;
  final AsyncValue<CatalogValue<Anime>> detail;
  final FavoriteEntry? savedEntry;
  final bool favoritesReady;
  final WatchEntry? resumeEntry;
  final bool isPad;
  final double hPad;
  final bool showFullSummary;
  final VoidCallback onToggleSummary;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onOpenCollection;
  final VoidCallback onOpenSources;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final heroUri = anime.poster ?? anime.cover;
    final count = anime.episodeCount;
    final resumeTime = resumeEntry != null &&
            resumeEntry!.progress.position > Duration.zero
        ? ' ${formatPlaybackTime(resumeEntry!.progress.position)}'
        : '';
    final playLabel = resumeEntry == null ? '立即播放' : '播放$resumeTime';

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiquidGlassCircleButton(
          icon: savedEntry != null
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: savedEntry == null ? '加入追番' : savedEntry!.status.label,
          active: savedEntry != null,
          onPressed: !favoritesReady ? null : onOpenCollection,
        ),
        const SizedBox(width: SpacingTokens.sm),
        LiquidGlassCircleButton(
          icon: Icons.video_library_outlined,
          label: '片源',
          onPressed: onOpenSources,
        ),
        const SizedBox(width: SpacingTokens.sm),
        LiquidGlassCircleButton(
          icon: Icons.refresh_rounded,
          label: '刷新资料',
          onPressed: onRefresh,
        ),
      ],
    );

    final playCta = SizedBox(
      width: isPad ? 290 : double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: onPlay,
        style: FilledButton.styleFrom(
          backgroundColor: ColorTokens.text,
          foregroundColor: ColorTokens.background,
          shape: const StadiumBorder(),
          textStyle: type.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: Text(playLabel),
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          anime.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: type.displaySmall?.copyWith(
            fontSize: isPad ? 34 : 26,
            height: 1.12,
            letterSpacing: -0.4,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
          ),
        ),
        if (anime.originalName.isNotEmpty && anime.originalName != anime.title)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              anime.originalName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );

    final metaAndSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (anime.score case final score?)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 17,
                    color: Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    score.toStringAsFixed(1),
                    style: type.labelLarge?.copyWith(color: ColorTokens.text),
                  ),
                ],
              ),
            if (anime.platform.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.36),
                  ),
                ),
                child: Text(
                  anime.platform,
                  style: type.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            if (anime.year case final y? when y.isNotEmpty)
              Text(
                y,
                style: type.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            if (count != null)
              Text(
                '$count 集',
                style: type.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            if (anime.tags.isNotEmpty)
              Text(
                anime.tags.take(3).join(' · '),
                style: type.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
          ],
        ),
        if (detail.value?.stale == true || detail.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '当前显示已保存的资料',
              style: type.bodySmall?.copyWith(color: ColorTokens.accent),
            ),
          ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          anime.summary.isEmpty ? '暂无简介' : anime.summary,
          maxLines: showFullSummary ? null : (isPad ? 3 : 4),
          overflow: showFullSummary ? null : TextOverflow.ellipsis,
          style: type.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.76),
            height: 1.45,
          ),
        ),
        if (anime.summary.length > 96)
          GestureDetector(
            onTap: onToggleSummary,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                showFullSummary ? '收起简介' : '展开简介',
                style: type.labelMedium?.copyWith(color: ColorTokens.accent),
              ),
            ),
          ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Transform.scale(
                    scale: 1.15,
                    child: Artwork(
                      uri: heroUri,
                      asset: heroUri == null ? localArtwork : null,
                      alignment: Alignment.topCenter,
                      decodeWidth: 640,
                    ),
                  ),
                ),
                Opacity(
                  opacity: isPad ? 0.48 : 0.42,
                  child: Artwork(
                    uri: heroUri,
                    asset: heroUri == null ? localArtwork : null,
                    alignment: isPad
                        ? const Alignment(0.28, -0.45)
                        : Alignment.topCenter,
                    decodeWidth: 960,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.28, 0.72, 1.0],
                      colors: [
                        Color(0x8A070B10),
                        Color(0x420A1018),
                        Color(0xD6101923),
                        ColorTokens.background,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              SpacingTokens.xs,
              hPad,
              SpacingTokens.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LiquidGlassCircleButton(
                      key: const ValueKey('ios-detail-back'),
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: '返回',
                      size: 40,
                      iconSize: 18,
                      onPressed: onBack,
                    ),
                    const Spacer(),
                    LiquidGlassCircleButton(
                      icon: Icons.video_library_outlined,
                      label: '片源',
                      size: 40,
                      iconSize: 19,
                      onPressed: onOpenSources,
                    ),
                  ],
                ),
                SizedBox(height: isPad ? 156 : 108),
                if (isPad)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 308,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleBlock,
                            const SizedBox(height: SpacingTokens.sm),
                            actionButtons,
                            const SizedBox(height: SpacingTokens.sm),
                            playCta,
                          ],
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.lg),
                      Expanded(child: metaAndSummary),
                    ],
                  )
                else ...[
                  titleBlock,
                  const SizedBox(height: SpacingTokens.sm),
                  actionButtons,
                  const SizedBox(height: SpacingTokens.sm),
                  playCta,
                  const SizedBox(height: SpacingTokens.md),
                  metaAndSummary,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IosEpisodeCard extends StatelessWidget {
  const _IosEpisodeCard({
    required this.anime,
    required this.episode,
    required this.watchEntry,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final Anime anime;
  final Episode episode;
  final WatchEntry? watchEntry;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final code = episode.kind == EpisodeKind.regular
        ? 'E${episode.number.toString().padLeft(2, '0')}'
        : episode.label;
    final heading = episode.title.isEmpty
        ? episode.label
        : '$code · ${episode.title}';
    final progressText = watchEntry != null
        ? watchEntry!.progress.completed
              ? '已看完'
              : '已观看 ${(watchEntry!.progress.fraction * 100).round()}%'
        : (episode.runningTime ?? '点击立即加载片源播放');

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Artwork(
                      uri: anime.cover ?? anime.poster,
                      asset: (anime.cover ?? anime.poster) == null
                          ? localArtwork
                          : null,
                      alignment: Alignment(
                        ((episode.number % 3) - 1) * 0.16,
                        -0.25,
                      ),
                      decodeWidth: 480,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.18, 1.0],
                          colors: [Color(0x38080D14), Color(0xC2080E16)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                    ),
                    if (episode.runningTime case final rt? when rt.isNotEmpty)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            rt,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: LiquidGlassSurface(
                        radius: RadiusTokens.pill,
                        blur: 8,
                        tint: const Color(0x66121C28),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
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
                          value: watchEntry!.progress.fraction.clamp(0.02, 1.0),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6BB5FF),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : Colors.white.withValues(alpha: 0.14),
                              width: selected ? 1.5 : 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? ColorTokens.text : Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              progressText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
