import 'dart:async';

import 'package:aniview/app/aniview_app.dart';
import 'package:aniview/app/providers.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/features/player/player_controls_bar.dart';
import 'package:aniview/media/android_media_access.dart';
import 'package:aniview/media/media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleAnime = Anime(
  id: 400602,
  chineseName: '葬送的芙莉莲',
  originalName: '葬送のフリーレン',
  date: '2026-11-18',
  tags: ['冒险', '奇幻', '治愈'],
  platform: 'TV',
  episodeCount: 28,
  summary: '精灵魔法使芙莉莲踏上了解人类与告别过往的旅途。这是一段关于时间、回忆与重逢的故事，用来检查 iPad 双栏详情布局。',
);

class _AdaptiveTestRepo implements AnimeRepository {
  const _AdaptiveTestRepo();

  @override
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0}) async* {
    yield const CatalogPage(
      items: [
        _sampleAnime,
        Anime(id: 52, chineseName: '钢之炼金术师', originalName: '鋼の錬金術師'),
      ],
      nextOffset: null,
    );
  }

  @override
  Future<CatalogValue<List<Episode>>> episodes(int subjectId) async =>
      const CatalogValue([
        Episode(id: 1, number: 1, title: '冒险的终点', runningTime: '24m'),
        Episode(id: 2, number: 2, title: '魔法使的旅途', runningTime: '24m'),
      ]);

  @override
  Stream<CatalogPage> search(SearchQuery query) async* {
    yield* browse(Catalog.all);
  }

  @override
  Future<CatalogValue<Anime>> subject(int id) async =>
      const CatalogValue(_sampleAnime);
}

Widget _buildAdaptiveApp() => ProviderScope(
  overrides: [
    animeRepositoryProvider.overrideWithValue(const _AdaptiveTestRepo()),
    favoriteEntriesProvider.overrideWith((_) => Stream.value(<FavoriteEntry>[])),
    favoritesProvider.overrideWith((_) => Stream.value(<Anime>[])),
    historyProvider.overrideWith((_) => Stream.value(<WatchEntry>[])),
    autoplayProvider.overrideWith((_) => Stream.value(true)),
    autoNextProvider.overrideWith((_) => Stream.value(true)),
    danmakuEndpointProvider.overrideWith((_) => Stream.value(null)),
    danmakuEndpointsProvider.overrideWith((_) => Stream.value(const [])),
  ],
  child: const AniViewApp(),
);

void main() {
  testWidgets(
    'iPhone 390x844 uses floating Liquid Glass pill nav and bouncing physics',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildAdaptiveApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('glass-nav')), findsOneWidget);
      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsNothing);
      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(
        scrollableState.position.physics.parent,
        isA<BouncingScrollPhysics>(),
      );

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('发现'), findsWidgets);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'rotated iPhone 844x390 stays compact without side rail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.reset);

      late bool sideRail;
      late bool wideTheatre;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(844, 390)),
          child: Builder(
            builder: (context) {
              sideRail = AdaptiveLayout.useSideRail(context);
              wideTheatre = AdaptiveLayout.useWideTheatre(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(sideRail, false);
      expect(wideTheatre, false);
    },
  );

  testWidgets(
    'iPad portrait 820x1180 and landscape 1180x820 render Liquid Glass rail, 2-col layouts, and theatre scaffold',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(820, 1180);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildAdaptiveApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('glass-nav')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('葬送的芙莉莲'), findsWidgets);

      await tester.tap(find.text('葬送的芙莉莲').first);
      await tester.pumpAndSettle();
      expect(find.text('冒险的终点'), findsOneWidget);
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1180, 820);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dim,
          home: PlayerScreenScaffold(
            full: false,
            fullScreen: false,
            viewport: const ColoredBox(color: Colors.black, child: Text('VP')),
            details: ListView(children: const [ListTile(title: Text('DetailsPanel'))]),
            onExitFullscreen: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final vpOffset = tester.getTopLeft(find.text('VP'));
      final detailsOffset = tester.getTopLeft(find.text('DetailsPanel'));
      expect(detailsOffset.dx, greaterThan(vpOffset.dx));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'AndroidMediaAccess accepts file:// on iOS and content:// on Android while rejecting untrusted schemes',
    (tester) async {
      const mediaChannel = MethodChannel('app.aniview/media');
      String nextUri =
          'file:///var/mobile/Containers/Data/Application/1/Documents/AniViewMedia/ep1.mkv';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        mediaChannel,
        (call) async {
          if (call.method == 'pickVideo') {
            return {'uri': nextUri, 'name': 'ep1.mkv'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          mediaChannel,
          null,
        ),
      );

      const bridge = AndroidMediaAccess();
      final iosPicked = await bridge.pickVideo();
      expect(iosPicked?.uri.scheme, 'file');
      expect(iosPicked?.name, 'ep1.mkv');

      nextUri = 'content://com.android.providers.media.documents/document/42';
      final androidPicked = await bridge.pickVideo();
      expect(androidPicked?.uri.scheme, 'content');

      nextUri = 'https://evil.example/video.mp4';
      expect(bridge.pickVideo(), throwsFormatException);
    },
  );
}
