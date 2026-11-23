import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../anime/anime.dart';

extension CatalogTitle on Catalog {
  String get title => switch (this) {
    Catalog.season => '本季新番',
    Catalog.popular => '热门推荐',
    Catalog.all => '番库',
    Catalog.ranking => 'Bangumi 榜单',
  };
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.catalog, this.focusSearch = false});

  final Catalog? catalog;
  final bool focusSearch;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  String? _tag;
  int? _year;
  int? _next;
  List<Anime> _results = [];
  bool _loading = true;
  bool _stale = false;
  Object? _failure;
  bool get _isSearch => widget.catalog == null;

  StreamSubscription<CatalogPage>? _subscription;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    if (widget.focusSearch) _focusSearch();
  }

  @override
  void didUpdateWidget(DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusSearch && !oldWidget.focusSearch) _focusSearch();
  }

  void _focusSearch() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focus.requestFocus();
  });

  void _scheduleSearch() {
    _debounce?.cancel();
    final delay = _search.value.composing.isValid ? 800 : 380;
    setState(() {
      _loading = true;
      _failure = null;
      _next = null;
    });
    _debounce = Timer(
      Duration(milliseconds: delay),
      () => _load(reset: true),
    );
  }

  void _submitSearch() {
    _debounce?.cancel();
    _focus.unfocus();
    _load(reset: true);
  }

  void _load({required bool reset}) {
    final offset = reset ? 0 : _next;
    if (offset == null) return;

    _subscription?.cancel();
    if (reset && _scroll.hasClients) _scroll.jumpTo(0);

    setState(() {
      _failure = null;
      _loading = true;
      if (reset) {
        _stale = false;
        _next = null;
        // DO NOT clear _results here to avoid flickering when we show cached immediately.
      }
    });

    final source = ref.read(animeRepositoryProvider);
    final stream = _isSearch
        ? source.search((
            keyword: _search.text.trim(),
            tag: _tag,
            year: _year,
            offset: offset,
          ))
        : source.browse(widget.catalog!, offset: offset);

    _subscription = stream.listen((result) {
      if (!mounted) return;
      setState(() {
        if (reset && !result.stale) {
          // It's a fresh result for a new search, we can replace completely.
          // Wait, if it's the very first yield (cache), it will have stale: true (if expired) or stale: false (if fresh).
          // We always want to replace the list on the first yield of a reset.
          // Since _results might hold previous query's results, we SHOULD clear it on the first yield.
        }
        if (reset && offset == 0) {
           // We are at the first page. The first yield replaces the list.
           // However, if we do this, the next yield (the network refresh) will also come here!
           // But since it's the SAME query, replacing the list with the fresh items is correct.
           _results = result.items;
           reset = false; // Next yields for this stream won't reset.
        } else {
           _results = {
             for (final anime in _results) anime.id: anime,
             for (final anime in result.items) anime.id: anime,
           }.values.toList();
        }
        _stale = result.stale;
        _next = result.nextOffset;
        _loading = false;
      });
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _failure = error;
        _loading = false;
      });
    }, onDone: () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _filter() async {
    _focus.unfocus();
    final result = await showModalBottomSheet<(String?, int?)>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: MotionTokens.sheetStyle(context),
      builder: (_) => _FilterSheet(tag: _tag, year: _year),
    );
    if (!mounted || result == null) return;
    if ((_tag, _year) == result) return;
    _tag = result.$1;
    _year = result.$2;
    _submitSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final filterLabel = [?_tag, if (_year != null) '$_year 年'].join(' · ');
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _isSearch ? null : AppBar(title: Text(widget.catalog!.title)),
      body: SafeArea(
        top: _isSearch,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LayoutTokens.contentMax,
            ),
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSearch) ...[
                          Text('发现', style: type.headlineSmall),
                          const SizedBox(height: SpacingTokens.md),
                          TextField(
                            controller: _search,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => _scheduleSearch(),
                            onSubmitted: (_) => _submitSearch(),
                            decoration: InputDecoration(
                              hintText: '搜索中文名或原文名',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清空搜索',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _search.clear();
                                        _submitSearch();
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.xs),
                          Wrap(
                            spacing: SpacingTokens.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SoftButton(
                                label: filterLabel.isEmpty ? '筛选' : filterLabel,
                                icon: Icons.tune_rounded,
                                onPressed: _filter,
                                selected: _tag != null || _year != null,
                                style: SoftStyle.outline,
                              ),
                              if (_tag != null || _year != null)
                                SoftButton(
                                  label: '清除筛选',
                                  style: SoftStyle.clear,
                                  onPressed: () {
                                    _tag = null;
                                    _year = null;
                                    _submitSearch();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.md),
                          Text(
                            _search.text.trim().isEmpty &&
                                    _tag == null &&
                                    _year == null
                                ? '浏览番剧'
                                : '搜索结果',
                            style: type.titleLarge,
                          ),
                        ],
                        if (_stale)
                          Row(
                            children: [
                              Text('当前显示本地缓存', style: type.bodySmall),
                              if (_failure != null) ...[
                                const SizedBox(width: SpacingTokens.xs),
                                Text('·', style: type.bodySmall),
                                const SizedBox(width: SpacingTokens.xs),
                                InkWell(
                                  onTap: () => _load(reset: true),
                                  child: Text('重试', style: type.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                                ),
                              ],
                            ],
                          ),
                        if (_loading && _results.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: SpacingTokens.lg,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: '正在加载番剧',
                              ),
                            ),
                          ),
                        if (!_loading && _results.isEmpty && _failure == null)
                          const Padding(
                            padding: EdgeInsets.only(top: SpacingTokens.sm),
                            child: StatusPanel(
                              icon: Icons.search_off_rounded,
                              title: '没有找到番剧',
                              message: '可以尝试更短的名称，或调整筛选条件。',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: SpacingTokens.horizontal,
                  sliver: SliverList.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SpacingTokens.xs),
                    itemBuilder: (_, index) =>
                        AnimeResultRow(anime: _results[index]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      SpacingTokens.md,
                      SpacingTokens.md,
                      SpacingTokens.md,
                      (_isSearch ? LayoutTokens.navReserve : SpacingTokens.lg) +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    child: _failure != null && _results.isEmpty
                        ? StatusPanel(
                            icon: Icons.cloud_off_outlined,
                            title: '加载失败',
                            message: '$_failure',
                            action: '重试',
                            onAction: () => _load(reset: true),
                          )
                        : _next != null || (_loading && _results.isNotEmpty)
                        ? Align(
                            child: SoftButton(
                              label: _loading ? '加载中…' : '加载更多',
                              onPressed: _loading
                                  ? null
                                  : () => _load(reset: false),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimeResultRow extends StatelessWidget {
  const AnimeResultRow({
    super.key,
    required this.anime,
    this.subtitle,
    this.trailing,
  });
  final Anime anime;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Panel(
    child: ListTile(
      contentPadding: SpacingTokens.horizontal,
      minTileHeight: 88,
      leading: SizedBox(
        width: 44,
        height: 58,
        child: ClipRRect(
          borderRadius: RadiusTokens.card,
          child: Artwork(uri: anime.cover, decodeWidth: 144),
        ),
      ),
      title: Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle ??
            [
              anime.year,
              anime.score == null
                  ? null
                  : 'Bangumi ${anime.score!.toStringAsFixed(1)}',
            ].nonNulls.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/anime/${anime.id}', extra: anime),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({this.tag, this.year});
  final String? tag;
  final int? year;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _tag = widget.tag;
  late int? _year = widget.year;
  static const _tags = ['冒险', '奇幻', '科幻', '日常', '校园', '恋爱', '悬疑', '运动'];

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year + 1;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          SpacingTokens.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('筛选番剧'),
            const SizedBox(height: SpacingTokens.md),
            Text('类型', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: SpacingTokens.xs),
            Wrap(
              spacing: SpacingTokens.xs,
              runSpacing: SpacingTokens.xs,
              children: [
                for (final tag in [null, ..._tags])
                  SoftButton(
                    label: tag ?? '全部',
                    selected: _tag == tag,
                    onPressed: () => setState(() => _tag = tag),
                    style: SoftStyle.outline,
                  ),
              ],
            ),
            const SizedBox(height: SpacingTokens.md),
            DropdownButtonFormField<int>(
              initialValue: _year ?? 0,
              decoration: const InputDecoration(labelText: '首播年份'),
              isExpanded: true,
              menuMaxHeight: 280,
              items: [
                const DropdownMenuItem(value: 0, child: Text('所有年份')),
                for (var y = year; y >= 1960; y--)
                  DropdownMenuItem(value: y, child: Text('$y 年')),
              ],
              onChanged: (value) =>
                  setState(() => _year = value == 0 ? null : value),
            ),
            const SizedBox(height: SpacingTokens.md),
            SizedBox(
              width: double.infinity,
              child: SoftButton(
                label: '应用筛选',
                style: SoftStyle.accent,
                onPressed: () => Navigator.of(context).pop((_tag, _year)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
