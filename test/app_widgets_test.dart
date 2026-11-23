import 'dart:async';

import 'package:aniview/app/aniview_app.dart';
import 'package:aniview/app/providers.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/core/widgets/soft_controls.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _example = Anime(
  id: 400602,
  chineseName: '测试的长番剧标题',
  originalName: 'テストタイトル',
  date: '2026-11-18',
  tags: ['冒险', '奇幻'],
  platform: 'TV',
  episodeCount: 12,
  summary: '测试首页布局用的番剧情节简介。该数据只在测试进程中使用。这里用于检查两行文字的裁切。',
);

class _Repository implements AnimeRepository {
  const _Repository();

  @override
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0}) async* {
      yield const CatalogPage(
        items: [
          _example,
          Anime(id: 52, originalName: '另一部番剧'),
        ],
        nextOffset: null,
      );
  }

  @override
  Future<CatalogValue<List<Episode>>> episodes(int subjectId) async =>
      const CatalogValue([Episode(id: 12, number: 1, title: '试播集')]);

  @override
  Stream<CatalogPage> search(SearchQuery query) async* {
    yield* browse(Catalog.all);
  }

  @override
  Future<CatalogValue<Anime>> subject(int id) async =>
      const CatalogValue(_example);
}

Widget _app([MediaResolver? resolver]) => ProviderScope(
  overrides: [
    animeRepositoryProvider.overrideWithValue(const _Repository()),
    favoriteEntriesProvider.overrideWith((_) => Stream.value(<FavoriteEntry>[])),
    favoritesProvider.overrideWith((_) => Stream.value(<Anime>[])),
    historyProvider.overrideWith((_) => Stream.value(<WatchEntry>[])),
    if (resolver != null) ...[
      resolverProvider.overrideWithValue(resolver),
      mediaProvider.overrideWith((_, _) async => null),
      autoplayProvider.overrideWith((_) => Stream.value(true)),
      autoNextProvider.overrideWith((_) => Stream.value(true)),
      danmakuEndpointProvider.overrideWith((_) => Stream.value(null)),
      danmakuEndpointsProvider.overrideWith((_) => Stream.value(const [])),
    ],
  ],
  child: const AniViewApp(),
);

const _testOffer = SourceOffer(
  sourceId: 'authorized-test',
  resourceId: 'test-episode',
  label: '测试片源',
);

class _PlaybackLookup implements MediaResolver {
  _PlaybackLookup(this.result);

  final Future<FetchResult> result;
  MediaSearchRequest? request;
  int launches = 0;

  @override
  Future<FetchResult> find(MediaSearchRequest request) {
    this.request = request;
    return result;
  }

  @override
  Stream<FetchResult> watch(MediaSearchRequest request) async* {
    yield await find(request);
  }

  @override
  Future<String?> preferredSource(int? subjectId) async => null;

  @override
  Future<MediaCandidate> save(
    MediaSearchRequest request,
    SourceOffer offer,
  ) async {
    launches++;
    return MediaCandidate.create(
      uri: Uri.parse('https://media.example/test.mp4'),
      kind: MediaKind.direct,
      sourceName: offer.label,
      request: request,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FetchResult _verifiedResult(SourceState state) => FetchResult([
  RankedOffer(
    _testOffer,
    const MatchEvidence(100, '测试绑定', verified: true),
    state,
    100,
  ),
], const {});

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('home, detail and insets at $width dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 24);
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('AniView'), findsOneWidget);
      expect(find.text('立即播放'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('AniView')).dy,
        greaterThanOrEqualTo(28),
      );
      final nav = tester.getRect(find.byKey(const ValueKey('glass-nav')));
      expect(nav.bottom, lessThanOrEqualTo(820));
      expect(nav.left, greaterThan(0));
      expect(nav.right, lessThan(width));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('测试的长番剧标题').first);
      await tester.pumpAndSettle();
      expect(find.text('番剧详情'), findsOneWidget);
      expect(find.text('Bangumi 评分  暂无'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('AniView'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'detail Play opens the player for the first regular episode automatically',
    (tester) async {
      final resolver = _PlaybackLookup(
        Future.value(_verifiedResult(SourceState.available)),
      );
      await tester.pumpWidget(_app(resolver));
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试的长番剧标题').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('立即播放'));
      await tester.pumpAndSettle();
      expect(resolver.request?.episode?.id, 12);
      expect(resolver.launches, 1);
      expect(find.text('播放器'), findsOneWidget);
      expect(find.text('播放来源'), findsNothing);
    },
  );

  testWidgets('does not offer automatic selection for a blocked source', (
    tester,
  ) async {
    final resolver = _PlaybackLookup(
      Future.value(_verifiedResult(SourceState.login)),
    );
    await tester.pumpWidget(_app(resolver));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即播放'));
    await tester.pumpAndSettle();
    expect(resolver.launches, 0);
    expect(find.text('播放来源'), findsOneWidget);
    expect(find.text('自动选择'), findsNothing);
    expect(find.text('测试片源'), findsOneWidget);
  });

  testWidgets(
    'back cancels navigation while autoplay is still looking up sources',
    (tester) async {
      final result = Completer<FetchResult>();
      final resolver = _PlaybackLookup(result.future);
      await tester.pumpWidget(_app(resolver));
      await tester.pumpAndSettle();
      await tester.tap(find.text('立即播放'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('正在查找可播放片源'), findsOneWidget);
      await tester.binding.handlePopRoute();
      result.complete(_verifiedResult(SourceState.available));
      await tester.pumpAndSettle();
      expect(resolver.launches, 0);
      expect(find.text('AniView'), findsOneWidget);
      expect(find.text('播放器'), findsNothing);
    },
  );

  testWidgets(
    'content tabs are independent from root tabs, with Android back dispatch',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('榜单'));
      await tester.pumpAndSettle();
      expect(find.text('Bangumi 榜单'), findsOneWidget);
      final home = tester.widget<SoftAction>(
        find.byKey(const ValueKey('nav-0')),
      );
      expect(home.selected, true);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('AniView'), findsOneWidget);
    },
  );

  testWidgets('soft control presses, restores and activates with keyboard', (
    tester,
  ) async {
    var activated = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dim,
        home: Scaffold(
          body: Center(
            child: SoftButton(label: '操作', onPressed: () => activated++),
          ),
        ),
      ),
    );
    final finder = find.byType(SoftButton);
    expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(MotionTokens.press);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .98);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(activated, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, 2);
  });

  testWidgets(
    'disabled button skips the press animation and reduced motion disables duration',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dim,
          home: const Scaffold(
            body: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Center(child: SoftButton(label: '不可用', onPressed: null)),
            ),
          ),
        ),
      );
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero);
      await tester.tap(find.text('不可用'));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    },
  );

  testWidgets('home activity sheet replaces notification placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('追番动态'));
    await tester.pumpAndSettle();
    expect(find.text('追番动态'), findsOneWidget);
    expect(find.text('通知服务尚未接入'), findsNothing);
    expect(find.text('本地开播提醒将在后续版本接入。'), findsOneWidget);
  });
}
