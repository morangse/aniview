import 'dart:convert';
import 'dart:io';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v1 database gains v2 and v3 schema without changing existing IDs or progress',
    () async {
      final folder = await Directory.systemTemp.createTemp('aniview-v1-upgrade');
      final file = File.fromUri(folder.uri.resolve('aniview.sqlite'));
      addTearDown(() async {
        await file.delete();
        await folder.delete();
      });
      final old = sqlite3.open(file.path);
      old.execute('''
      CREATE TABLE favorites (subject_id INTEGER NOT NULL PRIMARY KEY, metadata TEXT NOT NULL, added_at INTEGER NOT NULL);
      CREATE TABLE media_entries (id TEXT NOT NULL PRIMARY KEY, location TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
        source_name TEXT NOT NULL, subject_id INTEGER, episode_id INTEGER, episode_label TEXT, cover TEXT, added_at INTEGER NOT NULL);
      CREATE TABLE watch_sessions (media_id TEXT NOT NULL PRIMARY KEY REFERENCES media_entries (id) ON DELETE CASCADE,
        position_ms INTEGER NOT NULL, duration_ms INTEGER NOT NULL, completed INTEGER NOT NULL CHECK (completed IN (0,1)),
        watched_at INTEGER NOT NULL);
      CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE metadata_cache (key TEXT NOT NULL PRIMARY KEY, payload TEXT NOT NULL, expires_at INTEGER NOT NULL, stored_at INTEGER NOT NULL);
      CREATE INDEX media_episode ON media_entries (subject_id, episode_id);
      CREATE INDEX watch_recent ON watch_sessions (watched_at DESC);
      INSERT INTO media_entries VALUES ('unchanged-id','content://provider/movie.mp4','document','Title','clip.mp4',5,6,'EP 1',NULL,1);
      INSERT INTO watch_sessions VALUES ('unchanged-id',11200,34000,0,1);
      INSERT INTO preferences VALUES ('autoplay','false');
      INSERT INTO metadata_cache VALUES ('cache-key','{"id":5}',100,1);
      PRAGMA user_version=1;
    ''');
      old.execute('INSERT INTO favorites VALUES (5, ?, 1)', [
        jsonEncode({
          'id': 5,
          'originalName': 'Original',
          'chineseName': '收藏',
          'summary': '',
          'platform': '',
          'tags': [],
        }),
      ]);
      old.close();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final library = LocalLibrary(db);
      expect(await db.select(db.configuredSources).get(), isEmpty);
      expect(await db.select(db.episodeAttachments).get(), isEmpty);
      expect((await library.mediaById('unchanged-id'))?.episodeId, 6);
      expect(
        (await library.load('unchanged-id'))?.position.inMilliseconds,
        11200,
      );
      final entry = (await library.watchFavoriteEntries().first).single;
      expect(entry.anime.title, '收藏');
      expect(entry.status, CollectionStatus.doing);
      expect(entry.updatedAt.millisecondsSinceEpoch, 1);
      expect(entry.dirty, false);
      expect(await library.watchAutoplay().first, false);
      expect((await db.select(db.metadataCache).get()).single.key, 'cache-key');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        3,
      );
    },
  );

  test(
    'v2 database upgrades to v3 preserving existing sources and default collection status',
    () async {
      final folder = await Directory.systemTemp.createTemp('aniview-v2-upgrade');
      final file = File.fromUri(folder.uri.resolve('aniview.sqlite'));
      addTearDown(() async {
        await file.delete();
        await folder.delete();
      });
      final old = sqlite3.open(file.path);
      old.execute('''
      CREATE TABLE favorites (subject_id INTEGER NOT NULL PRIMARY KEY, metadata TEXT NOT NULL, added_at INTEGER NOT NULL);
      CREATE TABLE media_entries (id TEXT NOT NULL PRIMARY KEY, location TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
        source_name TEXT NOT NULL, subject_id INTEGER, episode_id INTEGER, episode_label TEXT, cover TEXT, added_at INTEGER NOT NULL);
      CREATE TABLE watch_sessions (media_id TEXT NOT NULL PRIMARY KEY REFERENCES media_entries (id) ON DELETE CASCADE,
        position_ms INTEGER NOT NULL, duration_ms INTEGER NOT NULL, completed INTEGER NOT NULL CHECK (completed IN (0,1)),
        watched_at INTEGER NOT NULL);
      CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE metadata_cache (key TEXT NOT NULL PRIMARY KEY, payload TEXT NOT NULL, expires_at INTEGER NOT NULL, stored_at INTEGER NOT NULL);
      CREATE TABLE configured_sources (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL, endpoint TEXT NOT NULL DEFAULT '',
        user_id TEXT NOT NULL DEFAULT '', enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)), priority INTEGER NOT NULL DEFAULT 0,
        offline_allowed INTEGER NOT NULL DEFAULT 0 CHECK (offline_allowed IN (0,1)), subject_title TEXT NOT NULL DEFAULT '',
        subject_id INTEGER, episode_id INTEGER);
      CREATE TABLE resource_matches (episode_key TEXT NOT NULL, resource_key TEXT NOT NULL, score INTEGER NOT NULL, reason TEXT NOT NULL,
        confirmed INTEGER NOT NULL DEFAULT 0 CHECK (confirmed IN (0,1)), PRIMARY KEY (episode_key, resource_key));
      CREATE TABLE media_links (media_id TEXT NOT NULL PRIMARY KEY REFERENCES media_entries (id) ON DELETE CASCADE,
        source_id TEXT NOT NULL, resource_key TEXT NOT NULL, resource_id TEXT NOT NULL);
      CREATE TABLE source_health_rows (id TEXT NOT NULL PRIMARY KEY, state TEXT NOT NULL, successes INTEGER NOT NULL DEFAULT 0,
        failures INTEGER NOT NULL DEFAULT 0, startup_ms INTEGER NOT NULL DEFAULT 0, buffers INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
      CREATE TABLE episode_attachments (id TEXT NOT NULL PRIMARY KEY, episode_key TEXT NOT NULL, kind TEXT NOT NULL, name TEXT NOT NULL, payload TEXT NOT NULL);
      CREATE TABLE download_tasks (id TEXT NOT NULL PRIMARY KEY, source_id TEXT NOT NULL, title TEXT NOT NULL, state TEXT NOT NULL,
        received INTEGER NOT NULL DEFAULT 0, total INTEGER, validator TEXT, checksum TEXT, error TEXT);
      CREATE TABLE sync_snapshots (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL);
      INSERT INTO configured_sources (id, kind, name) VALUES ('src-1', 'direct', 'Existing');
      PRAGMA user_version=2;
    ''');
      old.execute('INSERT INTO favorites VALUES (42, ?, 12345)', [
        jsonEncode({
          'id': 42,
          'originalName': 'Old Title',
          'chineseName': '旧条目',
          'summary': '',
          'platform': 'TV',
          'tags': [],
        }),
      ]);
      old.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final library = LocalLibrary(db);
      final entries = await library.watchFavoriteEntries().first;
      expect(entries, hasLength(1));
      expect(entries.single.anime.id, 42);
      expect(entries.single.status, CollectionStatus.doing);
      expect(entries.single.addedAt.millisecondsSinceEpoch, 12345);
      expect(entries.single.updatedAt.millisecondsSinceEpoch, 12345);
      expect(
        (await db.select(db.configuredSources).get()).single.name,
        'Existing',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        3,
      );
    },
  );
}
