import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/anime/anime.dart';
import '../../media/media.dart';
import 'app_database.dart';

class LocalLibrary implements MediaSource, WatchProgressRepository {
  const LocalLibrary(this.db);

  final AppDatabase db;

  Stream<List<FavoriteEntry>> watchFavoriteEntries() {
    final query = db.select(db.favorites)
      ..orderBy([
        (row) => OrderingTerm.desc(row.updatedAt),
        (row) => OrderingTerm.desc(row.addedAt),
      ]);
    return query.watch().map(
      (rows) => rows
          .map((row) {
            final updatedMs = row.updatedAt > 0 ? row.updatedAt : row.addedAt;
            return FavoriteEntry(
              anime: Anime.fromJson(
                jsonDecode(row.metadata) as Map<String, dynamic>,
              ),
              status: CollectionStatus.fromCode(row.status),
              rating: row.rating,
              comment: row.comment,
              addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
              dirty: row.dirty,
            );
          })
          .toList(growable: false),
    );
  }

  Stream<List<Anime>> watchFavorites() => watchFavoriteEntries().map(
    (entries) => entries.map((entry) => entry.anime).toList(growable: false),
  );

  Future<void> setFavorite(
    Anime anime,
    bool saved, {
    CollectionStatus status = CollectionStatus.doing,
    int? rating,
    String? comment,
    bool markDirty = true,
  }) async {
    final key = 'local-remove/${anime.id}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedRating =
        rating != null && rating >= 1 && rating <= 10 ? rating : null;
    final trimmed = comment?.trim();
    final normalizedComment =
        trimmed == null || trimmed.isEmpty ? null : trimmed;
    await db.transaction(() async {
      if (saved) {
        final existing = await (db.select(
          db.favorites,
        )..where((row) => row.subjectId.equals(anime.id))).getSingleOrNull();
        await db
            .into(db.favorites)
            .insertOnConflictUpdate(
              FavoritesCompanion(
                subjectId: Value(anime.id),
                metadata: Value(jsonEncode(anime.toJson())),
                addedAt: Value(existing?.addedAt ?? now),
                status: Value(status.code),
                rating: Value(normalizedRating),
                comment: Value(normalizedComment),
                updatedAt: Value(now),
                dirty: Value(markDirty),
              ),
            );
        await (db.delete(
          db.syncSnapshots,
        )..where((row) => row.key.equals(key))).go();
      } else {
        await (db.delete(
          db.favorites,
        )..where((row) => row.subjectId.equals(anime.id))).go();
        await db
            .into(db.syncSnapshots)
            .insertOnConflictUpdate(
              SyncSnapshot(key: key, value: '1', updatedAt: now),
            );
      }
    });
  }

  Future<void> setCollection(
    Anime anime,
    CollectionStatus status, {
    int? rating,
    String? comment,
    bool markDirty = true,
  }) => setFavorite(
    anime,
    true,
    status: status,
    rating: rating,
    comment: comment,
    markDirty: markDirty,
  );

  Future<void> clearFavoriteDirty(int subjectId) =>
      (db.update(db.favorites)..where((row) => row.subjectId.equals(subjectId)))
          .write(const FavoritesCompanion(dirty: Value(false)));

  Future<void> addMedia(MediaCandidate candidate) async {
    await db
        .into(db.mediaEntries)
        .insertOnConflictUpdate(
          MediaEntry(
            id: candidate.id,
            location: candidate.uri.toString(),
            kind: candidate.kind.name,
            title: candidate.title,
            sourceName: candidate.sourceName,
            subjectId: candidate.subjectId,
            episodeId: candidate.episodeId,
            episodeLabel: candidate.episodeLabel,
            cover: candidate.cover?.toString(),
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<MediaCandidate?> mediaById(String id) async {
    final row = await (db.select(
      db.mediaEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _candidate(row);
  }

  @override
  Future<List<MediaCandidate>> candidates(MediaRequest request) async {
    final id = request.anime?.id;
    if (id == null) return [];
    final episodeId = request.episode?.id;
    final query = db.select(db.mediaEntries)
      ..where(
        (row) =>
            row.subjectId.equals(id) &
            (episodeId == null
                ? const Constant(true)
                : row.episodeId.equals(episodeId)),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]);
    return (await query.get()).map(_candidate).toList(growable: false);
  }

  @override
  Future<WatchProgress?> load(String mediaId) async {
    final row = await (db.select(
      db.watchSessions,
    )..where((row) => row.mediaId.equals(mediaId))).getSingleOrNull();
    return row == null ? null : _progress(row);
  }

  @override
  Future<void> save(String mediaId, WatchProgress progress) async {
    final duration = progress.duration.inMilliseconds;
    if (duration <= 0) return;
    final position = progress.position.inMilliseconds.clamp(0, duration);
    await db.customInsert(
      '''
      INSERT INTO watch_sessions
        (media_id, position_ms, duration_ms, completed, watched_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(media_id) DO UPDATE SET
        position_ms = excluded.position_ms, duration_ms = excluded.duration_ms,
        completed = excluded.completed, watched_at = excluded.watched_at
      WHERE excluded.watched_at >= watch_sessions.watched_at
      ''',
      variables: [
        Variable(mediaId),
        Variable(position),
        Variable(duration),
        Variable(progress.completed),
        Variable(progress.updatedAt.millisecondsSinceEpoch),
      ],
      updates: {db.watchSessions},
    );
  }

  @override
  Stream<List<WatchEntry>> watchHistory() {
    final query =
        db.select(db.watchSessions).join([
            innerJoin(
              db.mediaEntries,
              db.mediaEntries.id.equalsExp(db.watchSessions.mediaId),
            ),
          ])
          ..orderBy([OrderingTerm.desc(db.watchSessions.watchedAt)])
          ..limit(100);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => WatchEntry(
              _candidate(row.readTable(db.mediaEntries)),
              _progress(row.readTable(db.watchSessions)),
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<bool> _watchBoolPref(String key) =>
      (db.select(db.preferences)..where((row) => row.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value != 'false');

  Future<void> _setBoolPref(String key, bool value) => db
      .into(db.preferences)
      .insertOnConflictUpdate(Preference(key: key, value: value.toString()));

  Stream<bool> watchAutoplay() => _watchBoolPref('autoplay');

  Future<void> setAutoplay(bool value) => _setBoolPref('autoplay', value);

  Stream<bool> watchAutoNext() => _watchBoolPref('auto_next');

  Future<void> setAutoNext(bool value) => _setBoolPref('auto_next', value);

  Stream<String?> watchDanmakuEndpoint() =>
      (db.select(db.preferences)
            ..where((row) => row.key.equals('danmaku.endpoint')))
          .watchSingleOrNull()
          .map((row) {
            final value = row?.value.trim();
            return value == null || value.isEmpty ? null : value;
          });

  static List<String> _mergeDanmakuEndpoints(
    String? listRaw,
    String? activeRaw,
  ) {
    final result = <String>[];
    final active = activeRaw?.trim() ?? '';
    if (active.isNotEmpty) result.add(active);
    if (listRaw != null && listRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(listRaw);
        if (decoded is List) {
          for (final item in decoded) {
            final value = item is String ? item.trim() : '';
            if (value.isNotEmpty && !result.contains(value)) {
              result.add(value);
            }
          }
        }
      } on FormatException {
        // Ignore malformed saved list.
      }
    }
    return List.unmodifiable(result);
  }

  Stream<List<String>> watchDanmakuEndpoints() =>
      (db.select(db.preferences)..where(
            (row) => row.key.isIn(const ['danmaku.endpoints', 'danmaku.endpoint']),
          ))
          .watch()
          .map((rows) {
            String? listRaw;
            String? activeRaw;
            for (final row in rows) {
              if (row.key == 'danmaku.endpoints') listRaw = row.value;
              if (row.key == 'danmaku.endpoint') activeRaw = row.value;
            }
            return _mergeDanmakuEndpoints(listRaw, activeRaw);
          });

  Future<void> setDanmakuEndpoint(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await (db.delete(
        db.preferences,
      )..where((row) => row.key.equals('danmaku.endpoint'))).go();
      return;
    }
    await addDanmakuEndpoint(trimmed, makeActive: true);
  }

  Future<void> addDanmakuEndpoint(
    String url, {
    bool makeActive = true,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final listRow = await (db.select(
      db.preferences,
    )..where((row) => row.key.equals('danmaku.endpoints'))).getSingleOrNull();
    final activeRow = await (db.select(
      db.preferences,
    )..where((row) => row.key.equals('danmaku.endpoint'))).getSingleOrNull();
    final others = _mergeDanmakuEndpoints(
      listRow?.value,
      activeRow?.value,
    ).where((e) => e != trimmed).toList();
    final nextList = makeActive ? [trimmed, ...others] : [...others, trimmed];
    await db
        .into(db.preferences)
        .insertOnConflictUpdate(
          Preference(key: 'danmaku.endpoints', value: jsonEncode(nextList)),
        );
    final hasActive = activeRow?.value.trim().isNotEmpty == true;
    if (makeActive || !hasActive) {
      await db
          .into(db.preferences)
          .insertOnConflictUpdate(
            Preference(key: 'danmaku.endpoint', value: trimmed),
          );
    }
  }

  Future<void> selectDanmakuEndpoint(String url) =>
      addDanmakuEndpoint(url, makeActive: true);

  Future<void> removeDanmakuEndpoint(String url) async {
    final trimmed = url.trim();
    final listRow = await (db.select(
      db.preferences,
    )..where((row) => row.key.equals('danmaku.endpoints'))).getSingleOrNull();
    final activeRow = await (db.select(
      db.preferences,
    )..where((row) => row.key.equals('danmaku.endpoint'))).getSingleOrNull();
    final remaining = _mergeDanmakuEndpoints(
      listRow?.value,
      activeRow?.value,
    ).where((e) => e != trimmed).toList();
    if (remaining.isEmpty) {
      await (db.delete(
        db.preferences,
      )..where((row) => row.key.equals('danmaku.endpoints'))).go();
      await (db.delete(
        db.preferences,
      )..where((row) => row.key.equals('danmaku.endpoint'))).go();
      return;
    }
    await db
        .into(db.preferences)
        .insertOnConflictUpdate(
          Preference(key: 'danmaku.endpoints', value: jsonEncode(remaining)),
        );
    if (activeRow?.value.trim() == trimmed) {
      await db
          .into(db.preferences)
          .insertOnConflictUpdate(
            Preference(key: 'danmaku.endpoint', value: remaining.first),
          );
    }
  }

  static WatchProgress _progress(WatchSession row) => WatchProgress(
    position: Duration(milliseconds: row.positionMs),
    duration: Duration(milliseconds: row.durationMs),
    completed: row.completed,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.watchedAt),
  );

  static MediaCandidate _candidate(MediaEntry row) => MediaCandidate(
    id: row.id,
    uri: Uri.parse(row.location),
    kind: MediaKind.values.byName(row.kind),
    title: row.title,
    sourceName: row.sourceName,
    subjectId: row.subjectId,
    episodeId: row.episodeId,
    episodeLabel: row.episodeLabel,
    cover: row.cover == null ? null : Uri.tryParse(row.cover!),
  );
}
