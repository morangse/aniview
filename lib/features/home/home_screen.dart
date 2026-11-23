import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/media.dart';
import '../anime/anime.dart';
import '../library/collection_sheet.dart';
import '../player/source_sheet.dart';
import 'ios_home_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  int _heroIndex = 0;
  static const _tabs = ['推荐', '新番', '番库', '榜单'];

  void _setTab(int index) => setState(() => _tab = index);
  void _changeHero(int index, int count) =>
      setState(() => _heroIndex = (index + count) % count);

  @override
  Widget build(BuildContext context) {
    final seasonal = ref.watch(catalogProvider(Catalog.season));
    final popular = ref.watch(catalogProvider(Catalog.popular));
    final history = ref.watch(historyProvider);
    final favorites = ref.watch(favoriteEntriesProvider);
    final favoriteEntries = favorites.value ?? const <FavoriteEntry>[];
    final seasonalItems = seasonal.value?.items ?? const <Anime>[];
    final popularItems = popular.value?.items ?? const <Anime>[];
    final spotlight = (seasonalItems.isNotEmpty ? seasonalItems : popularItems)
        .take(4)
        .toList();
    final entryById = {
      for (final entry in favoriteEntries) entry.anime.id: entry,
    };
    final safeHero = spotlight.isEmpty
        ? 0
        : _heroIndex.clamp(0, spotlight.length - 1);
    final current = spotlight.isEmpty ? null : spotlight[safeHero];

    final isApple = AdaptiveLayout.isApplePlatform;
    final isPad = AdaptiveLayout.isPad(context);
    final segmentedBar = LiquidGlassSegmentedBar(
      labels: _tabs,
      selectedIndex: _tab,
      onSelect: _setTab,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: MistBackdrop()),
          SafeArea(
            bottom: false,
            child: PageColumn(
              key: const PageStorageKey('home-scroll'),
              inShell: true,
              fullBleed: isApple,
              children: [
                Row(
                  children: [
                    const _Brand(),
                    const Spacer(),
                    if (isApple) ...[
                      LiquidGlassCircleButton(
                        icon: Icons.search_rounded,
                        label: '搜索',
                        size: 40,
                        iconSize: 20,
                        onPressed: () => context.go('/discover?focus=1'),
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      LiquidGlassCircleButton(
                        icon: Icons.notifications_none_rounded,
                        label: '追番动态',
                        size: 40,
                        iconSize: 20,
                        onPressed: () => _showActivitySheet(
                          context,
                          favoriteEntries,
                          history.value ?? const <WatchEntry>[],
                        ),
                      ),
                    ] else ...[
                      IconCapsuleButton(
                        icon: Icons.search_rounded,
                        label: '搜索',
                        onPressed: () => context.go('/discover?focus=1'),
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      IconCapsuleButton(
                        icon: Icons.notifications_none_rounded,
                        label: '追番动态',
                        onPressed: () => _showActivitySheet(
                          context,
                          favoriteEntries,
                          history.value ?? const <WatchEntry>[],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: SpacingTokens.xs),
                if (isPad)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: segmentedBar,
                    ),
                  )
                else
                  segmentedBar,
                const SizedBox(height: SpacingTokens.sm),
                if (_tab == 0) ...[
                  _HomeHero(
                    anime: current,
                    index: safeHero,
                    count: spotlight.length,
                    savedEntry: current == null ? null : entryById[current.id],
                    favoritesReady: favorites.hasValue,
                    onChange: spotlight.length > 1
                        ? (step) =>
                              _changeHero(safeHero + step, spotlight.length)
                        : null,
                    onPlay: current == null
                        ? () => showSources(context)
                        : () => playAutomatically(
                            context,
                            MediaRequest(anime: current),
                          ),
                  ),
                  SizedBox(height: isPad ? SpacingTokens.md : SpacingTokens.xs),
                  if (isApple)
                    IosSectionHeader(
                      title: '继续观看',
                      onTapAction: () => context.push('/history'),
                    )
                  else
                    SectionHeading(
                      '继续观看',
                      action: '查看全部',
                      onAction: () => context.push('/history'),
                    ),
                  _ContinueStrip(history: history),
                  SizedBox(height: isPad ? SpacingTokens.md : SpacingTokens.xs),
                  _CatalogStrip(
                    title: '本季新番',
                    catalog: Catalog.season,
                    page: seasonal,
                  ),
                  SizedBox(height: isPad ? SpacingTokens.md : SpacingTokens.xs),
                  _CatalogStrip(
                    title: '热门推荐',
                    catalog: Catalog.popular,
                    page: popular,
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  Panel(
                    child: ListTile(
                      leading: const Icon(
                        Icons.bookmark_outline_rounded,
                        color: ColorTokens.accent,
                      ),
                      title: const Text('我的追番'),
                      subtitle: favorites.value == null
                          ? null
                          : Text('${favoriteEntries.length} 部已收藏'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/library'),
                    ),
                  ),
                ] else
                  _CatalogGrid(
                    key: ValueKey(_tab),
                    catalog: [
                      Catalog.season,
                      Catalog.season,
                      Catalog.all,
                      Catalog.ranking,
                    ][_tab],
                    title: ['推荐', '本季新番', '全部番剧', 'Bangumi 榜单'][_tab],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivitySheet(
    BuildContext context,
    List<FavoriteEntry> entries,
    List<WatchEntry> history,
  ) {
    final activeWatch = history
        .where((entry) => !entry.progress.completed)
        .take(5)
        .toList();
    final doingList = entries
        .where((entry) => entry.status == CollectionStatus.doing)
        .take(6)
        .toList();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MotionTokens.sheetStyle(context),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.lg,
            0,
            SpacingTokens.lg,
            SpacingTokens.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading('追番动态'),
              const SizedBox(height: SpacingTokens.sm),
              if (activeWatch.isEmpty && doingList.isEmpty)
                StatusPanel(
                  icon: Icons.explore_outlined,
                  title: '暂无最近动态',
                  message: '去发现页将喜欢的番剧加入「在看」，即可在这里快速接续。',
                  action: '去发现',
                  onAction: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/discover');
                  },
                ),
              if (activeWatch.isNotEmpty) ...[
                Text(
                  '待续播',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: SpacingTokens.xs),
                for (final entry in activeWatch)
                  Panel(
                    child: ListTile(
                      leading: const Icon(
                        Icons.play_circle_outline_rounded,
                        color: ColorTokens.accent,
                      ),
                      title: Text(
                        entry.media.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          entry.media.episodeLabel,
                          '${(entry.progress.fraction * 100).round()}%',
                        ].nonNulls.join(' · '),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/player/${entry.media.id}');
                      },
                    ),
                  ),
                const SizedBox(height: SpacingTokens.sm),
              ],
              if (doingList.isNotEmpty) ...[
                Text(
                  '正在追番',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: SpacingTokens.xs),
                for (final entry in doingList)
                  Panel(
                    child: ListTile(
                      leading: const Icon(
                        Icons.bookmark_rounded,
                        color: ColorTokens.accent,
                      ),
                      title: Text(
                        entry.anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: entry.rating == null
                          ? const Text('在看')
                          : Text('在看 · ${entry.rating} 分'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push(
                          '/anime/${entry.anime.id}',
                          extra: entry.anime,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: SpacingTokens.sm),
              ],
              Text(
                '本地开播提醒将在后续版本接入。',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const ExcludeSemantics(
        child: CustomPaint(size: Size(30, 30), painter: _BrandMark()),
      ),
      const SizedBox(width: SpacingTokens.xs),
      Text(
        'AniView',
        style: Theme.of(context).textTheme.headlineSmall!
            .copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
      ),
    ],
  );
}

class _BrandMark extends CustomPainter {
  const _BrandMark();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final play = Path()
      ..moveTo(5, 6)
      ..quadraticBezierTo(5, 1, 10, 3)
      ..lineTo(28, 13)
      ..quadraticBezierTo(32, 16, 28, 19)
      ..lineTo(10, 29)
      ..quadraticBezierTo(5, 31, 5, 26)
      ..close();
    canvas.clipPath(play);
    final paint = Paint();
    canvas.drawPath(play, paint..color = ColorTokens.accent);
    canvas.drawPath(
      Path()
        ..moveTo(10, 2)
        ..lineTo(17, 15)
        ..lineTo(31, 15)
        ..lineTo(10, 2),
      paint
        ..color = Color.alphaBlend(
          ColorTokens.elevated.withValues(alpha: .20),
          ColorTokens.accent,
        ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, 29)
        ..lineTo(17, 15)
        ..lineTo(31, 18)
        ..lineTo(9, 29),
      paint
        ..color = Color.alphaBlend(
          ColorTokens.elevated.withValues(alpha: .56),
          ColorTokens.accent,
        ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 10)
        ..lineTo(22, 16)
        ..lineTo(12, 22)
        ..close(),
      paint..color = ColorTokens.background,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMark oldDelegate) => false;
}

class _HomeHero extends ConsumerWidget {
  const _HomeHero({
    required this.anime,
    required this.index,
    required this.count,
    required this.savedEntry,
    required this.favoritesReady,
    required this.onPlay,
    this.onChange,
  });

  final Anime? anime;
  final int index;
  final int count;
  final FavoriteEntry? savedEntry;
  final bool favoritesReady;
  final VoidCallback onPlay;
  final ValueChanged<int>? onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anime = this.anime;
    final type = Theme.of(context).textTheme;
    const genres = {'冒险', '奇幻', '治愈', '科幻', '校园', '恋爱', '日常', '悬疑', '运动', '喜剧'};
    final meta = [
      if (anime?.platform case final value? when value.isNotEmpty) value,
      ?anime?.year,
      if (anime?.episodeCount case final total?) '$total 集',
      if (anime != null) ...anime.tags.where(genres.contains).take(2),
    ].join(' · ');
    final isApple = AdaptiveLayout.isApplePlatform;
    final isPad = AdaptiveLayout.isPad(context);
    final isWide = AdaptiveLayout.isWideLayout(context);
    return GestureDetector(
      onHorizontalDragEnd: onChange == null
          ? null
          : (event) {
              final velocity = event.primaryVelocity ?? 0;
              if (velocity.abs() >= 100) onChange!(velocity < 0 ? 1 : -1);
            },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: RadiusTokens.hero,
          boxShadow: ShadowTokens.floating,
        ),
        child: ClipRRect(
          borderRadius: RadiusTokens.hero,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: ColorTokens.surface),
              ),
              Positioned.fill(
                left: (anime == null || isApple) ? 0 : 62,
                child: RepaintBoundary(
                  child: Artwork(
                    uri: anime?.poster ?? anime?.cover,
                    asset: anime == null ? localArtwork : null,
                    alignment: isApple
                        ? const Alignment(0.25, -0.35)
                        : const Alignment(.36, -.38),
                    decodeWidth: isPad ? 1280 : 920,
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      stops: [0, .36, .72, 1],
                      colors: [
                        ColorTokens.filmScrim,
                        Color(0xCA101923),
                        Color(0x30101923),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, .44, 1],
                      colors: [
                        Color(0x17101923),
                        Color(0x15101923),
                        Color(0xE6101923),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: RadiusTokens.hero,
                      border: Border.all(color: ColorTokens.border),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: isPad
                      ? 300.0
                      : isWide
                      ? 284.0
                      : LayoutTokens.heroMinHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isPad ? SpacingTokens.lg : SpacingTokens.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _HeroTag(
                        icon: anime == null
                            ? Icons.folder_open_rounded
                            : index == 0
                            ? Icons.local_fire_department_outlined
                            : Icons.auto_awesome_outlined,
                        text: anime == null
                            ? '本地播放'
                            : index == 0
                            ? '本季焦点'
                            : '热门推荐',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: SpacingTokens.sm,
                          bottom: SpacingTokens.sm,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: isPad
                              ? .52
                              : isWide
                              ? .64
                              : .82,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (anime == null)
                                Text('打开我的视频', style: type.displaySmall)
                              else
                                InkWell(
                                  borderRadius: RadiusTokens.card,
                                  onTap: () => context.push(
                                    '/anime/${anime.id}',
                                    extra: anime,
                                  ),
                                  child: Text(
                                    anime.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: type.displaySmall!.copyWith(
                                      fontFamily: 'serif',
                                    ),
                                  ),
                                ),
                              if (anime != null &&
                                  anime.originalName != anime.title) ...[
                                const SizedBox(height: SpacingTokens.xxs),
                                Text(
                                  anime.originalName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.bodySmall,
                                ),
                              ],
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.xs),
                                Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.bodySmall?.copyWith(
                                    color: ColorTokens.accent,
                                  ),
                                ),
                              ],
                              if (anime == null ||
                                  anime.summary.isNotEmpty) ...[
                                const SizedBox(height: SpacingTokens.xs),
                                Text(
                                  anime?.summary ?? '选择本地文件，或粘贴你有权访问的视频地址。',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.bodySmall?.copyWith(
                                    color: ColorTokens.text,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: SpacingTokens.xs,
                        runSpacing: SpacingTokens.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isApple)
                            FilledButton.icon(
                              onPressed: onPlay,
                              style: FilledButton.styleFrom(
                                backgroundColor: ColorTokens.text,
                                foregroundColor: ColorTokens.background,
                                shape: const StadiumBorder(),
                                minimumSize: const Size(124, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: Text(anime == null ? '选择片源' : '立即播放'),
                            )
                          else
                            SoftButton(
                              label: anime == null ? '选择片源' : '立即播放',
                              icon: Icons.play_arrow_rounded,
                              style: SoftStyle.accent,
                              onPressed: onPlay,
                            ),
                          if (anime != null)
                            if (isApple)
                              LiquidGlassCircleButton(
                                icon: savedEntry != null
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                label: savedEntry == null
                                    ? '加入追番'
                                    : savedEntry!.status.label,
                                active: savedEntry != null,
                                size: 44,
                                onPressed: !favoritesReady
                                    ? null
                                    : () => showCollectionSheet(
                                        context,
                                        ref,
                                        anime,
                                        savedEntry,
                                      ),
                              )
                            else
                              SoftButton(
                                label: savedEntry == null
                                    ? '加入追番'
                                    : savedEntry!.status.label,
                                icon: savedEntry != null
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                style: SoftStyle.outline,
                                selected: savedEntry != null,
                                onPressed: !favoritesReady
                                    ? null
                                    : () => showCollectionSheet(
                                        context,
                                        ref,
                                        anime,
                                        savedEntry,
                                      ),
                              )
                          else
                            SoftButton(
                              label: '发现番剧',
                              style: SoftStyle.outline,
                              onPressed: () => context.go('/discover'),
                            ),
                          if (onChange != null)
                            SoftAction(
                              label: '精选 ${index + 1}/$count，切换下一张',
                              style: SoftStyle.clear,
                              onPressed: () => onChange!(1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  count,
                                  (i) => AnimatedContainer(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    duration: MotionTokens.resolve(
                                      context,
                                      MotionTokens.transition,
                                    ),
                                    width: i == index ? 13 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius: RadiusTokens.pill,
                                      color: i == index
                                          ? ColorTokens.accent
                                          : ColorTokens.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: RadiusTokens.pill,
      border: Border.all(color: ColorTokens.faintBorder),
      color: ColorTokens.elevated.withValues(alpha: .9),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.xs,
        vertical: SpacingTokens.xxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ColorTokens.accent),
          const SizedBox(width: SpacingTokens.xxs),
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

class _ContinueStrip extends StatelessWidget {
  const _ContinueStrip({required this.history});
  final AsyncValue<List<WatchEntry>> history;

  @override
  Widget build(BuildContext context) => history.when(
    loading: () => const LinearProgressIndicator(),
    error: (_, _) =>
        const StatusPanel(icon: Icons.history_rounded, title: '无法读取观看记录'),
    data: (entries) {
      final active = entries
          .where((entry) => !entry.progress.completed)
          .take(10)
          .toList();
      if (active.isEmpty) {
        if (AdaptiveLayout.isApplePlatform) {
          return const IosEmptyContinueCard();
        }
        return Panel(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm,
            ),
            leading: const Icon(
              Icons.play_circle_outline_rounded,
              color: ColorTokens.accent,
            ),
            title: const Text('暂无继续观看的影片'),
            subtitle: const Text('从本地文件或播放地址开始'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showSources(context),
          ),
        );
      }
      if (AdaptiveLayout.isApplePlatform) {
        return SizedBox(
          height: IosContinueCard.cardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: active.length,
            separatorBuilder: (_, _) => SizedBox(
              width: AdaptiveLayout.isPad(context)
                  ? SpacingTokens.sm
                  : SpacingTokens.xs,
            ),
            itemBuilder: (_, index) => IosContinueCard(entry: active[index]),
          ),
        );
      }
      return SizedBox(
        height: LayoutTokens.progressCardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: active.length,
          separatorBuilder: (_, _) => const SizedBox(width: SpacingTokens.xs),
          itemBuilder: (context, index) {
            final entry = active[index];
            return SizedBox(
              width: LayoutTokens.progressWidth,
              child: SoftAction(
                radius: RadiusTokens.card,
                onPressed: () => context.push('/player/${entry.media.id}'),
                child: ClipRRect(
                  borderRadius: RadiusTokens.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: LayoutTokens.progressImageHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Artwork(
                              uri: entry.media.cover,
                              asset: entry.media.cover == null
                                  ? localArtwork
                                  : null,
                              alignment: Alignment.topCenter,
                              decodeWidth: 400,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    ColorTokens.filmScrim,
                                  ],
                                ),
                              ),
                            ),
                            const Positioned(
                              right: SpacingTokens.xs,
                              bottom: SpacingTokens.sm,
                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                size: 25,
                                color: ColorTokens.text,
                              ),
                            ),
                            Positioned(
                              bottom: SpacingTokens.xxs,
                              left: SpacingTokens.xs,
                              right: SpacingTokens.xs,
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                borderRadius: RadiusTokens.pill,
                                value: entry.progress.fraction,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.xs,
                          vertical: SpacingTokens.xxs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.media.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              [
                                entry.media.episodeLabel,
                                '${(entry.progress.fraction * 100).round()}%',
                              ].nonNulls.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: ColorTokens.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _CatalogStrip extends ConsumerWidget {
  const _CatalogStrip({
    required this.title,
    required this.catalog,
    required this.page,
  });
  final String title;
  final Catalog catalog;
  final AsyncValue<CatalogPage> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApple = AdaptiveLayout.isApplePlatform;
    final isPad = AdaptiveLayout.isPad(context);
    final count = page.value?.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isApple)
          IosSectionHeader(
            title: title,
            countLabel: count == null ? '查看全部' : '$count',
            onTapAction: () => context.push('/catalog/${catalog.name}'),
          )
        else
          SectionHeading(
            title,
            action: '查看全部',
            onAction: () => context.push('/catalog/${catalog.name}'),
          ),
        _CatalogStatus(
          page: page,
          retry: () => ref.invalidate(catalogProvider(catalog)),
          render: (result) {
            if (isApple) {
              return SizedBox(
                height: IosPosterCard.cardHeight(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: result.items.take(16).length,
                  separatorBuilder: (_, _) => SizedBox(
                    width: isPad ? SpacingTokens.sm : SpacingTokens.xs,
                  ),
                  itemBuilder: (context, index) => SizedBox(
                    width: IosPosterCard.cardWidth(context),
                    child: IosPosterCard(anime: result.items[index]),
                  ),
                ),
              );
            }
            return SizedBox(
              height: LayoutTokens.posterHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: result.items.take(12).length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: SpacingTokens.xs),
                itemBuilder: (context, index) => SizedBox(
                  width: LayoutTokens.posterWidth,
                  child: AnimeTile(anime: result.items[index]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CatalogGrid extends ConsumerWidget {
  const _CatalogGrid({super.key, required this.catalog, required this.title});
  final Catalog catalog;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApple = AdaptiveLayout.isApplePlatform;
    final isPad = AdaptiveLayout.isPad(context);
    final width = MediaQuery.sizeOf(context).width;
    final padCols = width >= 1050 ? 6 : 5;
    final appleCols = isPad ? padCols : 3;
    return Column(
      children: [
        if (isApple)
          IosSectionHeader(
            title: title,
            onTapAction: () => context.push('/catalog/${catalog.name}'),
          )
        else
          SectionHeading(
            title,
            action: '查看全部',
            onAction: () => context.push('/catalog/${catalog.name}'),
          ),
        _CatalogStatus(
          page: ref.watch(catalogProvider(catalog)),
          retry: () => ref.invalidate(catalogProvider(catalog)),
          render: (page) => GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: page.items.length,
            gridDelegate: isApple
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: appleCols,
                    childAspectRatio: 0.54,
                    crossAxisSpacing: isPad
                        ? SpacingTokens.sm
                        : SpacingTokens.xs,
                    mainAxisSpacing: SpacingTokens.md,
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AdaptiveLayout.gridColumns(context),
                    childAspectRatio: .67,
                    crossAxisSpacing: SpacingTokens.xs,
                    mainAxisSpacing: SpacingTokens.xs,
                  ),
            itemBuilder: (_, index) => isApple
                ? IosPosterCard(anime: page.items[index])
                : AnimeTile(anime: page.items[index]),
          ),
        ),
      ],
    );
  }
}

class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({
    required this.page,
    required this.retry,
    required this.render,
  });
  final AsyncValue<CatalogPage> page;
  final VoidCallback retry;
  final Widget Function(CatalogPage) render;

  @override
  Widget build(BuildContext context) => page.when(
    loading: () => const SizedBox(
      height: 52,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => StatusPanel(
      icon: Icons.cloud_off_outlined,
      title: '番剧列表暂不可用',
      message: '$error',
      action: '重试',
      onAction: retry,
    ),
    data: (data) => data.items.isEmpty
        ? const StatusPanel(icon: Icons.movie_outlined, title: '暂无番剧')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.stale)
                Padding(
                  padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                  child: Text(
                    '当前显示本地缓存',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              render(data),
            ],
          ),
  );
}

class AnimeTile extends StatelessWidget {
  const AnimeTile({super.key, required this.anime});
  final Anime anime;

  @override
  Widget build(BuildContext context) => SoftAction(
    radius: RadiusTokens.card,
    style: SoftStyle.surface,
    onPressed: () => context.push('/anime/${anime.id}', extra: anime),
    child: ClipRRect(
      borderRadius: RadiusTokens.card,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Artwork(
            uri: anime.cover,
            decodeWidth: 260,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.34, .72, 1],
                colors: [
                  Colors.transparent,
                  Color(0x62101923),
                  ColorTokens.filmScrim,
                ],
              ),
            ),
          ),
          Positioned(
            bottom: SpacingTokens.xs,
            left: SpacingTokens.xs,
            right: SpacingTokens.xs,
            child: Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    ),
  );
}
