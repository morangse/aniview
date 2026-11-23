import 'dart:io';

import 'package:aniview/app/aniview_app.dart';
import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/downloads/download_manager.dart';
import 'package:aniview/media/sources/catalog_subscription.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/test_vault.dart';

const _title = Anime(id: 400602, originalName: 'Integration QA');
const _firstEpisode = Episode(id: 8766, number: 1, title: 'First episode');
const _secondEpisode = Episode(id: 8767, number: 2, title: 'Second episode');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const server = String.fromEnvironment('ANIVIEW_QA_SERVER');

  testWidgets(
    'Home launches the first regular episode through an imported HLS catalog',
    (tester) async {
      expect(
        server,
        isNotEmpty,
        reason: 'Start the QA loopback server and provide ANIVIEW_QA_SERVER.',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final vault = TestVault();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          vaultProvider.overrideWithValue(vault),
          animeRepositoryProvider.overrideWithValue(const _Catalog()),
        ],
      );
      addTearDown(container.dispose);
      final store = container.read(sourceStoreProvider);
      for (final (id, path, priority, episode) in [
        ('wrong-episode-qa', 'test.m3u8', 10, _secondEpisode),
        ('failed-qa', 'missing.mp4', 5, _firstEpisode),
      ]) {
        await store.put(
          ConfiguredSource(
            id: id,
            name: id,
            kind: 'direct',
            endpoint: server,
            userId: '',
            enabled: true,
            priority: priority,
            offlineAllowed: false,
            subjectTitle: _title.title,
            subjectId: _title.id,
            episodeId: episode.id,
          ),
          secret: {'url': '$server/$path'},
        );
      }
      final registry = container.read(sourceRegistryProvider);
      final manifest = await CatalogSubscription.read(
        registry.http,
        '$server/catalog-subscription.json',
      );
      expect(manifest.members, hasLength(3));
      final imported = await manifest.importSelected(store, {
        for (final member in manifest.members) member.id,
      });
      expect(imported, (added: 3, skipped: 0));
      final request = MediaSearchRequest(anime: _title, episode: _firstEpisode);
      for (final member in manifest.members) {
        final adapter = await registry.enabledAdapter(member.sourceId);
        final offer = (await adapter.search(request)).single;
        final access = await adapter.resolve(offer.resourceId);
        expect(access.uri.path, anyOf('/test.m3u8', '/AniView-QA.mp4'));
        expect(offer.episodeId, _firstEpisode.id);
        expect(access.restrictOrigin, true);
        if (member.id != 'qa-json') {
          final config = (await store.byId(member.sourceId))!;
          await store.put(config.copyWith(enabled: false));
        }
      }
      final goodSource = manifest.members
          .singleWhere((entry) => entry.id == 'qa-json')
          .sourceId;
      debugPrint('ANIVIEW_IMPORTED_SOURCES JSON RSS Web');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AniViewApp(),
        ),
      );
      await _until(tester, find.text('立即播放'));
      await tester.tap(find.text('立即播放'));
      final scrubber = find.byKey(const ValueKey('seek-bar'));
      await _until(tester, scrubber, seconds: 39);
      expect(find.text('播放来源'), findsNothing);

      final linked = await db.select(db.mediaLinks).get();
      expect(linked.map((entry) => entry.sourceId).toSet(), {
        'failed-qa',
        goodSource,
      });
      final savedMedia = await db.select(db.mediaEntries).get();
      expect(savedMedia, hasLength(2));
      expect(
        savedMedia.map((entry) => entry.episodeId),
        everyElement(_firstEpisode.id),
      );
      final healthy = await store.health();
      expect(healthy['failed-qa/failed-qa']?.failures, 1);
      expect(
        await store.preference('preferred-source.${_title.id}'),
        goodSource,
      );

      final track = tester.getRect(scrubber);
      await tester.tapAt(
        Offset(track.left + track.width * .62, track.center.dy),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      final saved = await (db.select(
        db.watchSessions,
      )..orderBy([(row) => OrderingTerm.desc(row.watchedAt)])).get();
      expect(saved.first.positionMs, greaterThan(14000));
      expect(saved.first.positionMs, lessThan(30000));
      expect(
        savedMedia
            .singleWhere((entry) => entry.id == saved.first.mediaId)
            .episodeId,
        _firstEpisode.id,
      );
      final navigator = GoRouter.of(tester.element(find.text('AniView')));
      final reopened = navigator.push<void>('/player/${saved.first.mediaId}');
      await _until(tester, scrubber);
      final restored = tester.widget<Slider>(scrubber).value;
      expect(restored, greaterThanOrEqualTo(saved.first.positionMs - 500));
      debugPrint(
        'ANIVIEW_HLS_FAILOVER saved_position_ms=${saved.first.positionMs}',
      );
      debugPrint(
        'ANIVIEW_HLS_RESUMED restored_position_ms=${restored.round()}',
      );
      navigator.pop();
      await reopened;
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: server.isEmpty,
  );

  testWidgets(
    'Android download resumes an interrupted HTTP transfer and verifies the offline file',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'aniview-android-qa',
      );
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          vaultProvider.overrideWithValue(TestVault()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
        await directory.delete(recursive: true);
      });
      final resolver = container.read(resolverProvider);
      await resolver.store.put(
        ConfiguredSource(
          id: 'download-qa',
          name: 'Owned QA clip',
          kind: 'direct',
          endpoint: server,
          userId: '',
          enabled: true,
          priority: 0,
          offlineAllowed: true,
          subjectTitle: '',
        ),
        secret: {'url': '$server/interrupted/AniView-QA.mp4'},
      );
      final download = DownloadManager(
        resolver,
        () async => directory,
        directoryFreeSpace,
      );
      final id = await download.enqueue('download-qa');
      final failed = (await download.watch().first).single;
      expect(failed.state, 'failed');
      expect(failed.received, greaterThan(0));
      final resumed = DownloadManager(
        resolver,
        () async => directory,
        directoryFreeSpace,
      );
      await resumed.resume(id);
      final completed = (await resumed.watch().first).single;
      expect(completed.state, 'complete');
      expect(completed.total, completed.received);
      final media = await resumed.offlineMedia(completed);
      expect(await File.fromUri(media.uri).exists(), true);
      debugPrint(
        'ANIVIEW_ANDROID_RANGE partial=${failed.received} complete=${completed.received}',
      );
    },
    skip: server.isEmpty,
  );
}

Future<int?> directoryFreeSpace() async => null;

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  int seconds = 15,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 230));
  }
  expect(finder, findsOneWidget);
}

class _Catalog implements AnimeRepository {
  const _Catalog();
  @override
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0}) async* {
      yield const CatalogPage(items: [_title], nextOffset: null);
  }
  @override
  Stream<CatalogPage> search(SearchQuery query) => browse(Catalog.all);
  @override
  Future<CatalogValue<Anime>> subject(int id) async =>
      const CatalogValue(_title);
  @override
  Future<CatalogValue<List<Episode>>> episodes(int subjectId) async =>
      const CatalogValue([
        Episode(
          id: 8765,
          number: 0,
          title: 'Special',
          kind: EpisodeKind.special,
        ),
        _secondEpisode,
        _firstEpisode,
      ]);
}
