import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/backup_service.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/overlays/media_overlays.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  test('export and import restores 5-state collections, sources, attachments and protects newer progress', () async {
    final sourceDb = AppDatabase(NativeDatabase.memory());
    final vault = TestVault();
    await vault.write('source.src-1', {'token': 'super-secret-token'});
    final library = LocalLibrary(sourceDb);
    final store = SourceStore(sourceDb, vault);

    const anime = Anime(
      id: 77,
      originalName: 'Backup Original',
      chineseName: '备份测试番剧',
      platform: 'TV',
      episodeCount: 12,
    );
    const ep = Episode(id: 7701, number: 1, title: 'EP 1');
    await library.setCollection(
      anime,
      CollectionStatus.collected,
      rating: 10,
      comment: '神回',
    );
    await library.setAutoplay(false);

    await store.put(
      const ConfiguredSource(
        id: 'src-1',
        kind: 'jellyfin',
        name: 'Home NAS',
        endpoint: 'https://nas.example',
        userId: 'u1',
        enabled: true,
        priority: 3,
        offlineAllowed: false,
        subjectTitle: '',
      ),
      secret: {'token': 'super-secret-token'},
    );

    final media = MediaCandidate.create(
      uri: Uri.parse('aniview://media/src-1/res-1'),
      kind: MediaKind.direct,
      sourceName: 'Home NAS',
      request: const MediaRequest(anime: anime, episode: ep),
    );
    await library.addMedia(media);
    await store.link(
      MediaLink(
        mediaId: media.id,
        sourceId: 'src-1',
        resourceKey: 'src-1/res-1',
        resourceId: 'res-1',
      ),
    );
    await store.recordMatch(
      '77/7701',
      'src-1/res-1',
      const MatchEvidence(100, '手动确认', verified: true),
      confirmed: true,
    );
    await library.save(
      media.id,
      WatchProgress(
        position: const Duration(seconds: 120),
        duration: const Duration(minutes: 24),
        completed: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(10000),
      ),
    );
    await OverlayStore(store).add(
      media,
      'subtitle',
      'sub.srt',
      utf8.encode('1\n00:00:01,000 --> 00:00:03,000\nBackup line\n'),
    );

    final exported = await BackupService(sourceDb).exportJson();
    await sourceDb.close();
    expect(exported, isNot(contains('super-secret-token')));
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    expect(decoded['formatVersion'], 1);
    expect(decoded['schemaVersion'], 3);
    expect(decoded['includesSecrets'], false);

    final targetDb = AppDatabase(NativeDatabase.memory());
    addTearDown(targetDb.close);
    final targetLibrary = LocalLibrary(targetDb);
    final targetStore = SourceStore(targetDb, TestVault());

    // Pre-seed newer watch progress on targetDb to verify stale backups never overwrite it.
    await targetLibrary.addMedia(media);
    await targetLibrary.save(
      media.id,
      WatchProgress(
        position: const Duration(seconds: 600),
        duration: const Duration(minutes: 24),
        completed: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(50000),
      ),
    );

    final report = await BackupService(targetDb).importJson(exported);
    expect(report.favorites, 1);
    expect(report.mediaEntries, 1);
    expect(report.watchSessions, 1);
    expect(report.sources, 1);
    expect(report.attachments, 1);

    final fav = (await targetLibrary.watchFavoriteEntries().first).single;
    expect(fav.anime.title, '备份测试番剧');
    expect(fav.status, CollectionStatus.collected);
    expect(fav.rating, 10);
    expect(fav.comment, '神回');

    expect(await targetLibrary.watchAutoplay().first, false);
    expect((await targetStore.byId('src-1'))?.name, 'Home NAS');
    expect((await targetStore.linked(media.id))?.resourceId, 'res-1');
    expect((await targetStore.matches('77/7701'))['src-1/res-1']?.confirmed, true);
    expect(await targetDb.select(targetDb.episodeAttachments).get(), hasLength(1));

    // Newer local progress (600s) is preserved over older backup (120s).
    final progress = await targetLibrary.load(media.id);
    expect(progress?.position, const Duration(seconds: 600));
  });

  test('importJson rejects malformed JSON, wrong version and corrupt rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final service = BackupService(db);

    await expectLater(service.importJson('{not-json'), throwsFormatException);
    await expectLater(service.importJson('[]'), throwsFormatException);
    await expectLater(
      service.importJson(jsonEncode({'formatVersion': 99, 'schemaVersion': 3})),
      throwsFormatException,
    );
    await expectLater(
      service.importJson(
        jsonEncode({
          'formatVersion': 1,
          'schemaVersion': 3,
          'favorites': [
            {'subjectId': 'bad-int'},
          ],
        }),
      ),
      throwsFormatException,
    );
  });
}
