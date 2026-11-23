import 'dart:convert';

import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/features/player/player_screen.dart';
import 'package:aniview/features/player/skip_markers.dart';
import 'package:aniview/media/android_media_access.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/overlays/media_overlays.dart';
import 'package:aniview/media/playback_controller.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:aniview/media/subtitle_fonts.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

class _TestDeviceBridge implements PlayerDeviceBridge {
  _TestDeviceBridge({this.pipSupported = true});

  bool pipSupported;
  double windowBrightness = -1.0;
  int enteredPipCount = 0;
  final List<double> brightnessHistory = [];
  final List<bool> fullscreenHistory = [];
  final pipNotifier = ValueNotifier<bool>(false);

  @override
  Future<bool> enterPip({int width = 16, int height = 9}) async {
    enteredPipCount++;
    return pipSupported;
  }

  @override
  Future<double> getWindowBrightness() async => windowBrightness;

  @override
  ValueListenable<bool> get pipModeListenable => pipNotifier;

  @override
  Future<void> setFullscreen(bool full) async => fullscreenHistory.add(full);

  @override
  Future<void> setWindowBrightness(double value) async {
    windowBrightness = value;
    brightnessHistory.add(value);
  }

  @override
  Future<bool> supportsPip() async => pipSupported;

  void dispose() => pipNotifier.dispose();
}

class _M2FakePlaybackController extends ValueNotifier<PlaybackViewState>
    implements PlaybackController {
  _M2FakePlaybackController({
    PlaybackViewState initialState = const PlaybackViewState(
      opening: false,
      playing: true,
    ),
    Duration initialPosition = Duration.zero,
    Duration duration = const Duration(minutes: 24),
  }) : _position = ValueNotifier<Duration>(initialPosition),
       _duration = ValueNotifier<Duration>(duration),
       super(initialState);

  final ValueNotifier<Duration> _position;
  final ValueNotifier<Duration> _duration;
  final List<double> volumeHistory = [];
  final List<Duration> seekHistory = [];
  final List<String> audioTrackHistory = [];
  final List<({String payload, String title})> externalSubtitles = [];
  final List<int> subtitleDelays = [];
  int clearExternalSubtitleCount = 0;
  int pauseCount = 0;

  @override
  ValueListenable<Duration> get positionListenable => _position;

  @override
  ValueListenable<Duration> get durationListenable => _duration;

  void setPosition(Duration pos) => _position.value = pos;

  void updateState(PlaybackViewState next) => value = next;

  @override
  Widget buildSurface() => const ColoredBox(color: Colors.black);

  @override
  Future<void> open({required bool autoplay}) async {}

  @override
  Future<void> toggle() async {}

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekHistory.add(position);
    _position.value = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 150.0).toDouble();
    volumeHistory.add(clamped);
    value = PlaybackViewState(
      opening: value.opening,
      buffering: value.buffering,
      playing: value.playing,
      completed: value.completed,
      volume: clamped,
      rate: value.rate,
      aspectRatio: value.aspectRatio,
      subtitles: value.subtitles,
      selectedSubtitle: value.selectedSubtitle,
      audioTracks: value.audioTracks,
      selectedAudio: value.selectedAudio,
      error: value.error,
      storageError: value.storageError,
    );
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setAudioTrack(String id) async {
    audioTrackHistory.add(id);
    value = PlaybackViewState(
      opening: value.opening,
      buffering: value.buffering,
      playing: value.playing,
      completed: value.completed,
      volume: value.volume,
      rate: value.rate,
      aspectRatio: value.aspectRatio,
      subtitles: value.subtitles,
      selectedSubtitle: value.selectedSubtitle,
      audioTracks: value.audioTracks,
      selectedAudio: id,
      error: value.error,
      storageError: value.storageError,
    );
  }

  @override
  Future<void> setSubtitle(String id) async {}

  @override
  Future<void> setExternalSubtitle({
    required String payload,
    required String title,
  }) async {
    externalSubtitles.add((payload: payload, title: title));
  }

  @override
  Future<void> clearExternalSubtitle() async {
    clearExternalSubtitleCount++;
  }

  @override
  Future<void> setSubtitleDelayMs(int offsetMs) async {
    subtitleDelays.add(offsetMs);
  }

  @override
  Future<void> saveProgress() async {}

  @override
  Future<void> close() async {
    _position.dispose();
    _duration.dispose();
    dispose();
  }
}

class _TestAnimeRepo implements AnimeRepository {
  const _TestAnimeRepo();

  static const anime = Anime(id: 1, chineseName: '测试动画', originalName: 'Test');
  static const ep1 = Episode(id: 101, number: 1, title: '第一话');
  static const ep2 = Episode(id: 102, number: 2, title: '第二话');

  @override
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0}) async* {}

  @override
  Future<CatalogValue<List<Episode>>> episodes(int subjectId) async =>
      const CatalogValue([ep1, ep2]);

  @override
  Stream<CatalogPage> search(SearchQuery query) async* {}

  @override
  Future<CatalogValue<Anime>> subject(int id) async =>
      const CatalogValue(anime);
}

Widget _buildPlayerHost({
  required AppDatabase db,
  required MediaCandidate candidate,
  required _M2FakePlaybackController controller,
  required _TestDeviceBridge device,
  bool autoNext = true,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    vaultProvider.overrideWithValue(TestVault()),
    animeRepositoryProvider.overrideWithValue(const _TestAnimeRepo()),
    mediaProvider.overrideWith((_, _) async => candidate),
    autoplayProvider.overrideWith((_) => Stream.value(true)),
    autoNextProvider.overrideWith((_) => Stream.value(autoNext)),
    danmakuEndpointProvider.overrideWith((_) => Stream.value(null)),
    danmakuEndpointsProvider.overrideWith((_) => Stream.value(const [])),
    playerDeviceBridgeProvider.overrideWithValue(device),
    playbackFactoryProvider.overrideWithValue((_, _) => controller),
    favoriteEntriesProvider.overrideWith((_) => Stream.value(<FavoriteEntry>[])),
    favoritesProvider.overrideWith((_) => Stream.value(<Anime>[])),
    historyProvider.overrideWith((_) => Stream.value(<WatchEntry>[])),
  ],
  child: MaterialApp(
    theme: AppTheme.dim,
    home: PlayerScreen(mediaId: candidate.id),
  ),
);

void main() {
  test('SkipMarkers checks intro/outro ranges and serializes cleanly', () {
    const markers = SkipMarkers(introEndMs: 90000, outroDurationMs: 60000);
    const total = Duration(minutes: 24);
    expect(markers.isEmpty, false);
    expect(markers.inIntro(const Duration(seconds: 30), total), true);
    expect(markers.inIntro(const Duration(seconds: 95), total), false);
    expect(markers.inOutro(const Duration(minutes: 22), total), false);
    expect(
      markers.inOutro(const Duration(minutes: 23, seconds: 10), total),
      true,
    );
    expect(
      markers.inOutro(const Duration(minutes: 23, seconds: 59, milliseconds: 500), total),
      false,
    );
    final cleared = markers.copyWith(introEndMs: null);
    expect(cleared.introEndMs, isNull);
    expect(cleared.outroDurationMs, 60000);
    final roundTrip = SkipMarkers.fromJson(markers.toJson());
    expect(roundTrip.introEndMs, 90000);
    expect(roundTrip.outroDurationMs, 60000);
    expect(SubtitleFontConfig.bundledAsset, 'assets/fonts/NotoSansSC-Regular.otf');
  });

  testWidgets('vertical drags adjust brightness and 150% volume, horizontal drag seeks, and dispose restores brightness', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 700);
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge();
    addTearDown(device.dispose);
    final controller = _M2FakePlaybackController(
      initialPosition: const Duration(minutes: 1),
    );
    final candidate = MediaCandidate(
      id: 'm2-gestures',
      uri: Uri.parse('https://media.example/ep1.mp4'),
      kind: MediaKind.direct,
      title: 'Gestures',
      sourceName: 'ep1.mp4',
      subjectId: 1,
      episodeId: 101,
    );

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('player-gesture-area')));
    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.25, rect.center.dy),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(device.brightnessHistory, isNotEmpty);
    expect(device.brightnessHistory.last, greaterThan(0.5));

    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.75, rect.center.dy),
      const Offset(0, -350),
    );
    await tester.pump();
    expect(controller.volumeHistory, isNotEmpty);
    expect(controller.volumeHistory.last, 150.0);

    await tester.dragFrom(rect.center, const Offset(120, 0));
    await tester.pump();
    expect(controller.seekHistory, isNotEmpty);
    expect(controller.seekHistory.last, greaterThan(const Duration(minutes: 1)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(device.brightnessHistory.last, -1.0);
  });

  testWidgets('screen lock is fullscreen-only, blocks gestures/controls and tap reveals unlock control', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 480);
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge();
    addTearDown(device.dispose);
    final controller = _M2FakePlaybackController();
    final candidate = MediaCandidate(
      id: 'm2-lock',
      uri: Uri.parse('https://media.example/ep1.mp4'),
      kind: MediaKind.direct,
      title: 'Lock Test',
      sourceName: 'ep1.mp4',
    );

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-lock-button')), findsNothing);
    await tester.tap(find.byTooltip('全屏'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('seek-bar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-lock-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('seek-bar')), findsNothing);

    final gesture = find.byKey(const ValueKey('player-gesture-area'));
    await tester.dragFrom(tester.getCenter(gesture) - const Offset(80, 0), const Offset(0, -100));
    await tester.drag(gesture, const Offset(100, 0));
    await tester.pump();
    expect(device.brightnessHistory, isEmpty);
    expect(controller.seekHistory, isEmpty);

    await tester.tap(gesture);
    await tester.pump();
    final unlockFinder = find.byKey(const ValueKey('player-lock-button'));
    expect(unlockFinder, findsOneWidget);
    await tester.tap(unlockFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seek-bar')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('unified settings switches audio tracks and PiP hides controls & skips lifecycle pause', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge(pipSupported: true);
    addTearDown(device.dispose);
    final controller = _M2FakePlaybackController(
      initialState: const PlaybackViewState(
        opening: false,
        playing: true,
        audioTracks: [
          (id: '1', label: '日语 · jpn'),
          (id: '2', label: '中文 · chi'),
        ],
        selectedAudio: '1',
      ),
    );
    final candidate = MediaCandidate(
      id: 'm2-audio-pip',
      uri: Uri.parse('https://media.example/ep1.mkv'),
      kind: MediaKind.direct,
      title: 'Audio PiP',
      sourceName: 'ep1.mkv',
    );

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('字幕音轨'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文 · chi'));
    await tester.pumpAndSettle();
    expect(controller.audioTrackHistory, ['2']);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pip-button')));
    await tester.pump();
    expect(device.enteredPipCount, 1);

    device.pipNotifier.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('seek-bar')), findsNothing);
    expect(find.byKey(const ValueKey('player-gesture-area')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.pauseCount, 0);

    device.pipNotifier.value = false;
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.pauseCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('OP/ED skip pills seek/advance and auto-next countdown supports cancel', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge(pipSupported: false);
    addTearDown(device.dispose);
    final sourceStore = SourceStore(db, TestVault());
    await SkipMarkersStore(sourceStore).save(
      1,
      const SkipMarkers(introEndMs: 90000, outroDurationMs: 60000),
    );
    final controller = _M2FakePlaybackController(
      initialPosition: const Duration(seconds: 25),
      duration: const Duration(minutes: 24),
    );
    final candidate = MediaCandidate(
      id: 'm2-skip-next',
      uri: Uri.parse('https://media.example/ep1.mp4'),
      kind: MediaKind.direct,
      title: 'Skip Next',
      sourceName: 'ep1.mp4',
      subjectId: 1,
      episodeId: 101,
    );

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('skip-intro-pill')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip-intro-pill')));
    await tester.pump();
    expect(controller.seekHistory.last, const Duration(milliseconds: 90000));

    controller.setPosition(const Duration(minutes: 23, seconds: 10));
    await tester.pump();
    expect(find.byKey(const ValueKey('skip-outro-pill')), findsOneWidget);

    controller.updateState(
      const PlaybackViewState(
        opening: false,
        playing: false,
        completed: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('auto-next-overlay')), findsOneWidget);
    expect(find.text('5 秒后播放下一集'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3 秒后播放下一集'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(find.byKey(const ValueKey('auto-next-overlay')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('external ASS subtitle routes through controller libass methods with offset', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge(pipSupported: false);
    addTearDown(device.dispose);
    final controller = _M2FakePlaybackController();
    final candidate = MediaCandidate(
      id: 'm2-ass',
      uri: Uri.parse('https://media.example/ep1.mkv'),
      kind: MediaKind.direct,
      title: 'ASS Sub',
      sourceName: 'ep1.mkv',
    );
    const assPayload =
        '[Script Info]\nScriptType: v4.00+\n[Events]\nDialogue: 0,0:00:01.00,0:00:08.00,Default,,0,0,0,,ASS测试行\n';
    final store = OverlayStore(SourceStore(db, TestVault()));
    final ass = await store.add(
      candidate,
      'subtitle',
      'fansub.ass',
      utf8.encode(assPayload),
    );
    await store.save(candidate, {'subtitleId': ass.id, 'subtitleOffset': 500});

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.externalSubtitles, hasLength(1));
    expect(controller.externalSubtitles.single.title, 'fansub.ass');
    expect(controller.externalSubtitles.single.payload, assPayload);
    expect(controller.subtitleDelays, [500]);
    expect(find.text('ASS测试行'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('quick danmaku toggle flips enabled state, fullscreen opens right drawer, and composer sends local danmaku', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 480);
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final device = _TestDeviceBridge(pipSupported: false);
    addTearDown(device.dispose);
    final controller = _M2FakePlaybackController(
      initialPosition: const Duration(seconds: 12),
    );
    final candidate = MediaCandidate(
      id: 'm2-danmaku-ui',
      uri: Uri.parse('https://media.example/ep1.mp4'),
      kind: MediaKind.direct,
      title: 'Danmaku UI',
      sourceName: 'ep1.mp4',
    );
    final store = OverlayStore(SourceStore(db, TestVault()));
    final row = await store.add(
      candidate,
      'danmaku',
      'ep1.xml',
      utf8.encode('<i><d p="12,1,25,16777215">初始弹幕</d></i>'),
    );
    await store.save(candidate, {'danmakuId': row.id, 'danmakuEnabled': false});

    await tester.pumpWidget(
      _buildPlayerHost(
        db: db,
        candidate: candidate,
        controller: controller,
        device: device,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pumpSettled([int steps = 10]) async {
      await tester.pump();
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.tap(find.byKey(const ValueKey('danmaku-quick-toggle')));
    await pumpSettled();
    expect((await store.load(candidate)).settings.danmakuEnabled, true);

    await tester.tap(find.byTooltip('全屏'));
    await pumpSettled();
    await tester.tap(find.byKey(const ValueKey('player-settings-button')));
    await pumpSettled();
    expect(find.byKey(const ValueKey('player-right-drawer')), findsOneWidget);
    expect(find.text('弹幕'), findsOneWidget);
    expect(find.text('选集片源'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await pumpSettled();
    expect(find.byKey(const ValueKey('player-right-drawer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('danmaku-send-button')));
    await pumpSettled();
    await tester.enterText(find.byType(TextField), '名场面打卡');
    await tester.tap(find.text('发送'));
    await pumpSettled();

    final reloaded = await store.load(candidate);
    expect(reloaded.settings.danmakuEnabled, true);
    expect(
      reloaded.danmaku?.items.map((e) => e.text).toList(),
      contains('名场面打卡'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
