import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Favorites extends Table {
  IntColumn get subjectId => integer()();
  TextColumn get metadata => text()();
  IntColumn get addedAt => integer()();
  IntColumn get status => integer().withDefault(const Constant(3))();
  IntColumn get rating => integer().nullable()();
  TextColumn get comment => text().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {subjectId};
}

class MediaEntries extends Table {
  TextColumn get id => text()();
  TextColumn get location => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get sourceName => text()();
  IntColumn get subjectId => integer().nullable()();
  IntColumn get episodeId => integer().nullable()();
  TextColumn get episodeLabel => text().nullable()();
  TextColumn get cover => text().nullable()();
  IntColumn get addedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WatchSessions extends Table {
  TextColumn get mediaId =>
      text().references(MediaEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  BoolColumn get completed => boolean()();
  IntColumn get watchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class MetadataCache extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  IntColumn get expiresAt => integer()();
  IntColumn get storedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ConfiguredSources extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get endpoint => text().withDefault(const Constant(''))();
  TextColumn get userId => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get offlineAllowed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get subjectTitle => text().withDefault(const Constant(''))();
  IntColumn get subjectId => integer().nullable()();
  IntColumn get episodeId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ResourceMatches extends Table {
  TextColumn get episodeKey => text()();
  TextColumn get resourceKey => text()();
  IntColumn get score => integer()();
  TextColumn get reason => text()();
  BoolColumn get confirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {episodeKey, resourceKey};
}

class MediaLinks extends Table {
  TextColumn get mediaId =>
      text().references(MediaEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceId => text()();
  TextColumn get resourceKey => text()();
  TextColumn get resourceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId};
}

class SourceHealthRows extends Table {
  TextColumn get id => text()();
  TextColumn get state => text()();
  IntColumn get successes => integer().withDefault(const Constant(0))();
  IntColumn get failures => integer().withDefault(const Constant(0))();
  IntColumn get startupMs => integer().withDefault(const Constant(0))();
  IntColumn get buffers => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class EpisodeAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get episodeKey => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get title => text()();
  TextColumn get state => text()();
  IntColumn get received => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().nullable()();
  TextColumn get validator => text().nullable()();
  TextColumn get checksum => text().nullable()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncSnapshots extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Favorites,
    MediaEntries,
    WatchSessions,
    Preferences,
    MetadataCache,
    ConfiguredSources,
    ResourceMatches,
    MediaLinks,
    SourceHealthRows,
    EpisodeAttachments,
    DownloadTasks,
    SyncSnapshots,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(
    LazyDatabase(() async {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, 'aniview.sqlite')),
      );
    }),
  );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE INDEX media_episode ON media_entries (subject_id, episode_id)',
      );
      await customStatement(
        'CREATE INDEX watch_recent ON watch_sessions (watched_at DESC)',
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > to || to > 3) {
        throw UnsupportedError('No AniView schema migration from $from to $to');
      }
      await transaction(() async {
        if (from < 2) {
          for (final table in <TableInfo<Table, Object?>>[
            configuredSources,
            resourceMatches,
            mediaLinks,
            sourceHealthRows,
            episodeAttachments,
            downloadTasks,
            syncSnapshots,
          ]) {
            await migrator.createTable(table);
          }
        }
        if (from < 3) {
          await migrator.addColumn(favorites, favorites.status);
          await migrator.addColumn(favorites, favorites.rating);
          await migrator.addColumn(favorites, favorites.comment);
          await migrator.addColumn(favorites, favorites.updatedAt);
          await migrator.addColumn(favorites, favorites.dirty);
          await customStatement(
            'UPDATE favorites SET updated_at = added_at WHERE updated_at = 0',
          );
        }
      });
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
