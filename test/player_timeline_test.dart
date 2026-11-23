import 'dart:convert';

import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/features/player/player_screen.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/overlays/media_overlays.dart';
import 'package:aniview/media/playback_controller.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

class _FakePlaybackController extends ValueNotifier<PlaybackViewState>
    implements PlaybackController {
  _FakePlaybackController()
    : super(const PlaybackViewState(opening: false, playing: true));

  final _position = ValueNotifier<Duration>(Duration.zero);
  final _duration = ValueNotifier<Duration>(const Duration(minutes: 2));
  int surfaceBuildCount = 0;

  @override
  ValueListenable<Duration> get positionListenable => _position;

  @override
  ValueListenable<Duration> get durationListenable => _duration;

  void setPosition(Duration pos) => _position.value = pos;

  @override
  Widget buildSurface() {
    surfaceBuildCount++;
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<void> open({required bool autoplay}) async {
    value = const PlaybackViewState(opening: false, playing: true);
  }

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

void main() {
  testWidgets(
    'position updates drive timeline and subtitles without rebuilding PlaybackViewState listeners',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _FakePlaybackController();

      final candidate = MediaCandidate(
        id: 'm1',
        uri: Uri.parse('https://media.example/video.mp4'),
        kind: MediaKind.direct,
        title: 'Timeline Test',
        sourceName: 'test.mp4',
      );
      final store = OverlayStore(SourceStore(db, TestVault()));
      final sub = await store.add(
        candidate,
        'subtitle',
        'test.srt',
        utf8.encode('1\n00:00:05,000 --> 00:00:08,000\nLine at 5s\n'),
      );
      await store.save(candidate, {'subtitleId': sub.id});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            vaultProvider.overrideWithValue(TestVault()),
            mediaProvider.overrideWith((_, _) async => candidate),
            autoplayProvider.overrideWith((_) => Stream.value(true)),
            autoNextProvider.overrideWith((_) => Stream.value(true)),
            danmakuEndpointProvider.overrideWith((_) => Stream.value(null)),
            danmakuEndpointsProvider.overrideWith((_) => Stream.value(const [])),
            playbackFactoryProvider.overrideWithValue((_, _) => controller),
            favoriteEntriesProvider.overrideWith(
              (_) => Stream.value(<FavoriteEntry>[]),
            ),
            favoritesProvider.overrideWith((_) => Stream.value(<Anime>[])),
            historyProvider.overrideWith((_) => Stream.value(<WatchEntry>[])),
          ],
          child: MaterialApp(
            theme: AppTheme.dim,
            home: const PlayerScreen(mediaId: 'm1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Line at 5s'), findsNothing);
      final initialSurfaceBuilds = controller.surfaceBuildCount;

      var stateNotifications = 0;
      controller.addListener(() => stateNotifications++);

      for (var s = 1; s <= 6; s++) {
        controller.setPosition(Duration(seconds: s));
        await tester.pump();
      }

      expect(find.text('00:06'), findsOneWidget);
      expect(find.text('Line at 5s'), findsWidgets);
      expect(stateNotifications, 0);
      expect(controller.surfaceBuildCount, initialSurfaceBuilds);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
