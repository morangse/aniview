import 'dart:async';

import 'package:aniview/app/aniview_app.dart';
import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/features/player/player_controls_bar.dart';
import 'package:aniview/features/player/player_screen.dart';
import 'package:aniview/features/player/skip_markers.dart';
import 'package:aniview/media/android_media_access.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/playback_controller.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

const _sampleAnime = Anime(
  id: 400602,
  chineseName: '葬送的芙莉莲',
  originalName: '葬送のフリーレン',
  date: '2026-11-18',
  score: 9.2,
  tags: ['冒险', '奇幻', '治愈'],
  platform: 'TV',
  episodeCount: 28,
  summary: '精灵魔法使芙莉莲踏上了解人类与告别过往的旅途。这是一段关于时间、回忆与重逢的故事，用来检查 iPad 详情布局与无缝选源。',
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

class _FakePlaybackController extends ValueNotifier<PlaybackViewState>
    implements PlaybackController {
  _FakePlaybackController()
    : _position = ValueNotifier(const Duration(seconds: 45)),
      _duration = ValueNotifier(const Duration(minutes: 24)),
      super(const PlaybackViewState(opening: false, playing: true));

  final ValueNotifier<Duration> _position;
  final ValueNotifier<Duration> _duration;

  @override
  ValueListenable<Duration> get positionListenable => _position;

  @override
  ValueListenable<Duration> get durationListenable => _duration;

  @override
  Widget buildSurface() => const ColoredBox(color: Colors.black);

  @override
  Future<void> open({required bool autoplay}) async {}

  @override
  Future<void> toggle() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async => _position.value = position;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setAudioTrack(String id) async {}

  @override
  Future<void> setSubtitle(String id) async {}

  @override
  Future<void> setExternalSubtitle({
    required String payload,
    required String title,
  }) async {}

  @override
  Future<void> clearExternalSubtitle() async {}

  @override
  Future<void> setSubtitleDelayMs(int offsetMs) async {}

  @override
  Future<void> saveProgress() async {}

  @override
  Future<void> close() async {
    _position.dispose();
    _duration.dispose();
    dispose();
  }
}

class _FakeDeviceBridge implements PlayerDeviceBridge {
  final _pip = ValueNotifier<bool>(false);

  @override
  Future<bool> enterPip({int width = 16, int height = 9}) async => true;

  @override
  Future<double> getWindowBrightness() async => -1;

  @override
  ValueListenable<bool> get pipModeListenable => _pip;

  @override
  Future<void> setFullscreen(bool full) async {}

  @override
  Future<void> setWindowBrightness(double value) async {}

  @override
  Future<bool> supportsPip() async => false;

  void dispose() => _pip.dispose();
}

class _FakeFeedSource implements AuthorizedApiSource {
  const _FakeFeedSource();

  @override
  String get id => 'ios-rss';

  @override
  String get name => '测试订阅源';

  @override
  int get priority => 1;

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final ep = request.episode?.number ?? 1;
    return [
      SourceOffer(
        sourceId: id,
        resourceId: 'ep-$ep',
        label:
            '[LoliHouse] 葬送的芙莉莲 - ${ep.toString().padLeft(2, '0')} [WebRip 1080p HEVC].mp4',
      ),
    ];
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async =>
      StreamAccess(Uri.parse('https://video.example/$resourceId.mp4'));

  @override
  Future<void> testConnection() async {}
}

Widget _buildAdaptiveApp({List<dynamic> extraOverrides = const []}) =>
    ProviderScope(
      overrides: [
        animeRepositoryProvider.overrideWithValue(const _AdaptiveTestRepo()),
        favoriteEntriesProvider.overrideWith(
          (_) => Stream.value(<FavoriteEntry>[]),
        ),
        favoritesProvider.overrideWith((_) => Stream.value(<Anime>[])),
        historyProvider.overrideWith((_) => Stream.value(<WatchEntry>[])),
        autoplayProvider.overrideWith((_) => Stream.value(true)),
        autoNextProvider.overrideWith((_) => Stream.value(true)),
        danmakuEndpointProvider.overrideWith((_) => Stream.value(null)),
        danmakuEndpointsProvider.overrideWith((_) => Stream.value(const [])),
        ...extraOverrides.cast(),
      ],
      child: const AniViewApp(),
    );

void main() {
  testWidgets(
    'iPhone 390x844 uses unified floating Liquid Glass dock without overlapping borders',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildAdaptiveApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ios-liquid-dock')), findsOneWidget);
      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsNothing);
      expect(find.byKey(const ValueKey('glass-nav')), findsNothing);
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
    'iPad 820x1180 and 1180x820 render full-bleed layout, centered Liquid Glass dock, and SenPlayer detail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(820, 1180);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildAdaptiveApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ios-liquid-dock')), findsOneWidget);
      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('葬送的芙莉莲'), findsWidgets);

      await tester.tap(find.text('葬送的芙莉莲').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('冒险的终点'), findsWidgets);
      expect(find.text('演职人员'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ios-detail-back')));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1180, 820);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ios-liquid-dock')), findsOneWidget);
      expect(find.byKey(const ValueKey('liquid-glass-rail')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dim,
          home: PlayerScreenScaffold(
            full: false,
            fullScreen: false,
            viewport: const ColoredBox(color: Colors.black, child: Text('VP')),
            details: ListView(
              children: const [ListTile(title: Text('DetailsPanel'))],
            ),
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
    'iOS minimal fullscreen PlayerControlsFooter renders tags and transport controls without heavy card overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController();
      addTearDown(() => unawaited(controller.close()));

      final candidate = MediaCandidate(
        id: 'ios-full-1',
        uri: Uri.parse('https://video.example/01.mp4'),
        kind: MediaKind.direct,
        title: '葬送的芙莉莲',
        sourceName: '[LoliHouse] 葬送的芙莉莲 - 01 [WebRip 1080p HEVC].mp4',
        episodeLabel: '第 1 集',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dim,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PlayerControlsFooter(
                controller: controller,
                state: controller.value,
                full: true,
                danmakuEnabled: true,
                skipMarkers: const SkipMarkers(),
                candidate: candidate,
                onTogglePlayback: () {},
                onSeek: (_) async {},
                onKeepControlsVisible: () {},
                onScheduleHideControls: () {},
                onToggleFullscreen: () {},
                onToggleDanmaku: () {},
                onOpenComposer: () {},
                onPlayNext: () {},
                onPlayPrevious: () {},
                onOpenEpisodes: () {},
                onOpenSpeed: () {},
                onOpenSubtitles: () {},
                onToggleLock: () {},
                onSkipSeconds: (_) {},
                onSwitchSource: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LoliHouse'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('HEVC'), findsOneWidget);
      expect(find.byKey(const ValueKey('player-lock-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle-playback')), findsOneWidget);
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS direct-to-player resolves inside player, confirms Ep1 to remember source, and auto-launches Ep2',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final http = createMediaHttp();
      final device = _FakeDeviceBridge();
      addTearDown(db.close);
      addTearDown(http.close);
      addTearDown(device.dispose);

      final vault = TestVault();
      final store = SourceStore(db, vault);
      final library = LocalLibrary(db);
      final registry = MediaSourceRegistry(
        store,
        library,
        http,
        authorized: const [_FakeFeedSource()],
      );

      try {
        await tester.pumpWidget(
          _buildAdaptiveApp(
            extraOverrides: [
              databaseProvider.overrideWithValue(db),
              vaultProvider.overrideWithValue(vault),
              sourceStoreProvider.overrideWithValue(store),
              libraryProvider.overrideWithValue(library),
              sourceRegistryProvider.overrideWithValue(registry),
              playerDeviceBridgeProvider.overrideWithValue(device),
              playbackFactoryProvider.overrideWithValue(
                (_, _) => _FakePlaybackController(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('立即播放'));
        await tester.pumpAndSettle();

        // Enters in-player resolution view showing candidate right in place.
        final offerFinder = find.byKey(
          const ValueKey('inplayer-offer-ios-rss/ep-1'),
        );
        expect(offerFinder, findsOneWidget);
        await tester.tap(offerFinder);
        await tester.pumpAndSettle();

        // Seamless transition straight into active PlayerScreen.
        expect(find.byKey(const ValueKey('player-gesture-area')), findsOneWidget);
        expect(
          await MediaResolver(registry, store, library).verifiedSource(400602),
          'ios-rss',
        );

        // Go back and pick Episode 2 — now auto-resolves & launches straight to player!
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('葬送的芙莉莲').first);
        await tester.pumpAndSettle();
        final ep2Text = find.textContaining('魔法使的旅途').first;
        await tester.ensureVisible(ep2Text);
        await tester.tap(ep2Text);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byKey(const ValueKey('player-gesture-area')).evaluate().isNotEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('player-gesture-area')), findsOneWidget);
        expect(find.text('第 2 集'), findsWidgets);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
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
