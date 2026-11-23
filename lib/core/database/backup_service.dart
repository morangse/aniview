import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

class BackupImportReport {
  const BackupImportReport({
    required this.favorites,
    required this.mediaEntries,
    required this.watchSessions,
    required this.sources,
    required this.attachments,
  });

  final int favorites;
  final int mediaEntries;
  final int watchSessions;
  final int sources;
  final int attachments;
}

class BackupService {
  const BackupService(this.db);

  static const int formatVersion = 1;
  static const int supportedSchemaVersion = 3;

  final AppDatabase db;

  /// Exports local user data without SecureVault credentials or tokens.
  Future<String> exportJson({DateTime? now}) async {
    final favorites = await db.select(db.favorites).get();
    final mediaEntries = await db.select(db.mediaEntries).get();
    final watchSessions = await db.select(db.watchSessions).get();
    final preferences = await db.select(db.preferences).get();
    final sources = await db.select(db.configuredSources).get();
    final matches = await db.select(db.resourceMatches).get();
    final links = await db.select(db.mediaLinks).get();
    final attachments = await db.select(db.episodeAttachments).get();

    final payload = {
      'formatVersion': formatVersion,
      'schemaVersion': supportedSchemaVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'includesSecrets': false,
      'favorites': [
        for (final row in favorites)
          {
            'subjectId': row.subjectId,
            'metadata': row.metadata,
            'addedAt': row.addedAt,
            'status': row.status,
            'rating': row.rating,
            'comment': row.comment,
            'updatedAt': row.updatedAt,
            'dirty': row.dirty,
          },
      ],
      'mediaEntries': [
        for (final row in mediaEntries)
          {
            'id': row.id,
            'location': row.location,
            'kind': row.kind,
            'title': row.title,
            'sourceName': row.sourceName,
            'subjectId': row.subjectId,
            'episodeId': row.episodeId,
            'episodeLabel': row.episodeLabel,
            'cover': row.cover,
            'addedAt': row.addedAt,
          },
      ],
      'watchSessions': [
        for (final row in watchSessions)
          {
            'mediaId': row.mediaId,
            'positionMs': row.positionMs,
            'durationMs': row.durationMs,
            'completed': row.completed,
            'watchedAt': row.watchedAt,
          },
      ],
      'preferences': [
        for (final row in preferences) {'key': row.key, 'value': row.value},
      ],
      'configuredSources': [
        for (final row in sources)
          {
            'id': row.id,
            'kind': row.kind,
            'name': row.name,
            'endpoint': row.endpoint,
            'userId': row.userId,
            'enabled': row.enabled,
            'priority': row.priority,
            'offlineAllowed': row.offlineAllowed,
            'subjectTitle': row.subjectTitle,
            'subjectId': row.subjectId,
            'episodeId': row.episodeId,
          },
      ],
      'resourceMatches': [
        for (final row in matches)
          {
            'episodeKey': row.episodeKey,
            'resourceKey': row.resourceKey,
            'score': row.score,
            'reason': row.reason,
            'confirmed': row.confirmed,
          },
      ],
      'mediaLinks': [
        for (final row in links)
          {
            'mediaId': row.mediaId,
            'sourceId': row.sourceId,
            'resourceKey': row.resourceKey,
            'resourceId': row.resourceId,
          },
      ],
      'episodeAttachments': [
        for (final row in attachments)
          {
            'id': row.id,
            'episodeKey': row.episodeKey,
            'kind': row.kind,
            'name': row.name,
            'payload': row.payload,
          },
      ],
    };
    return jsonEncode(payload);
  }

  Future<BackupImportReport> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('备份文件不是有效的 JSON 格式。');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件根结构无效。');
    }
    final version = decoded['formatVersion'];
    final schema = decoded['schemaVersion'];
    if (version != formatVersion ||
        schema is! int ||
        schema < 1 ||
        schema > supportedSchemaVersion) {
      throw const FormatException('不支持的备份版本，请使用兼容版本导出。');
    }

    final favorites = _rows(decoded, 'favorites').map((row) {
      final addedAt = _reqInt(row, 'addedAt');
      final updatedAt = row['updatedAt'] as int? ?? addedAt;
      return FavoritesCompanion(
        subjectId: Value(_reqInt(row, 'subjectId')),
        metadata: Value(_reqString(row, 'metadata')),
        addedAt: Value(addedAt),
        status: Value(row['status'] as int? ?? 3),
        rating: Value(row['rating'] as int?),
        comment: Value(row['comment'] as String?),
        updatedAt: Value(updatedAt),
        dirty: Value(row['dirty'] as bool? ?? false),
      );
    }).toList();

    final mediaEntries = _rows(decoded, 'mediaEntries').map((row) {
      return MediaEntriesCompanion(
        id: Value(_reqString(row, 'id')),
        location: Value(_reqString(row, 'location')),
        kind: Value(_reqString(row, 'kind')),
        title: Value(_reqString(row, 'title')),
        sourceName: Value(_reqString(row, 'sourceName')),
        subjectId: Value(row['subjectId'] as int?),
        episodeId: Value(row['episodeId'] as int?),
        episodeLabel: Value(row['episodeLabel'] as String?),
        cover: Value(row['cover'] as String?),
        addedAt: Value(_reqInt(row, 'addedAt')),
      );
    }).toList();

    final watchSessions = _rows(decoded, 'watchSessions').map((row) {
      return WatchSession(
        mediaId: _reqString(row, 'mediaId'),
        positionMs: _reqInt(row, 'positionMs'),
        durationMs: _reqInt(row, 'durationMs'),
        completed: _reqBool(row, 'completed'),
        watchedAt: _reqInt(row, 'watchedAt'),
      );
    }).toList();

    final preferences = _rows(decoded, 'preferences').map((row) {
      return Preference(
        key: _reqString(row, 'key'),
        value: _reqString(row, 'value'),
      );
    }).toList();

    final sources = _rows(decoded, 'configuredSources').map((row) {
      return ConfiguredSourcesCompanion(
        id: Value(_reqString(row, 'id')),
        kind: Value(_reqString(row, 'kind')),
        name: Value(_reqString(row, 'name')),
        endpoint: Value(row['endpoint'] as String? ?? ''),
        userId: Value(row['userId'] as String? ?? ''),
        enabled: Value(row['enabled'] as bool? ?? true),
        priority: Value(row['priority'] as int? ?? 0),
        offlineAllowed: Value(row['offlineAllowed'] as bool? ?? false),
        subjectTitle: Value(row['subjectTitle'] as String? ?? ''),
        subjectId: Value(row['subjectId'] as int?),
        episodeId: Value(row['episodeId'] as int?),
      );
    }).toList();

    final matches = _rows(decoded, 'resourceMatches').map((row) {
      return ResourceMatche(
        episodeKey: _reqString(row, 'episodeKey'),
        resourceKey: _reqString(row, 'resourceKey'),
        score: _reqInt(row, 'score'),
        reason: _reqString(row, 'reason'),
        confirmed: row['confirmed'] as bool? ?? false,
      );
    }).toList();

    final links = _rows(decoded, 'mediaLinks').map((row) {
      return MediaLink(
        mediaId: _reqString(row, 'mediaId'),
        sourceId: _reqString(row, 'sourceId'),
        resourceKey: _reqString(row, 'resourceKey'),
        resourceId: _reqString(row, 'resourceId'),
      );
    }).toList();

    final attachments = _rows(decoded, 'episodeAttachments').map((row) {
      return EpisodeAttachment(
        id: _reqString(row, 'id'),
        episodeKey: _reqString(row, 'episodeKey'),
        kind: _reqString(row, 'kind'),
        name: _reqString(row, 'name'),
        payload: _reqString(row, 'payload'),
      );
    }).toList();

    await db.transaction(() async {
      for (final row in favorites) {
        await db.into(db.favorites).insertOnConflictUpdate(row);
      }
      for (final row in mediaEntries) {
        await db.into(db.mediaEntries).insertOnConflictUpdate(row);
      }
      for (final row in watchSessions) {
        await db.customInsert(
          '''
          INSERT INTO watch_sessions
            (media_id, position_ms, duration_ms, completed, watched_at)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(media_id) DO UPDATE SET
            position_ms = excluded.position_ms,
            duration_ms = excluded.duration_ms,
            completed = excluded.completed,
            watched_at = excluded.watched_at
          WHERE excluded.watched_at >= watch_sessions.watched_at
          ''',
          variables: [
            Variable(row.mediaId),
            Variable(row.positionMs),
            Variable(row.durationMs),
            Variable(row.completed),
            Variable(row.watchedAt),
          ],
          updates: {db.watchSessions},
        );
      }
      for (final row in preferences) {
        await db.into(db.preferences).insertOnConflictUpdate(row);
      }
      for (final row in sources) {
        await db.into(db.configuredSources).insertOnConflictUpdate(row);
      }
      for (final row in matches) {
        await db.into(db.resourceMatches).insertOnConflictUpdate(row);
      }
      for (final row in links) {
        await db.into(db.mediaLinks).insertOnConflictUpdate(row);
      }
      for (final row in attachments) {
        await db.into(db.episodeAttachments).insertOnConflictUpdate(row);
      }
    });

    return BackupImportReport(
      favorites: favorites.length,
      mediaEntries: mediaEntries.length,
      watchSessions: watchSessions.length,
      sources: sources.length,
      attachments: attachments.length,
    );
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> root,
    String key,
  ) {
    final value = root[key];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('备份字段 $key 格式无效。');
    }
    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          item
        else
          throw FormatException('备份字段 $key 包含损坏记录。'),
    ];
  }

  static String _reqString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String) return value;
    throw FormatException('备份记录缺少有效字段 $key。');
  }

  static int _reqInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    throw FormatException('备份记录缺少有效整数字段 $key。');
  }

  static bool _reqBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    throw FormatException('备份记录缺少有效布尔字段 $key。');
  }
}
