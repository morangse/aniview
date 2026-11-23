import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/secure_vault.dart';
import 'source_models.dart';

class SourceStore {
  const SourceStore(this.db, this.vault);
  final AppDatabase db;
  final CredentialVault vault;

  static const defaultSources = [
    ConfiguredSource(
      id: 'local',
      name: '本地文件',
      kind: 'local',
      endpoint: '',
      userId: '',
      enabled: true,
      priority: 5,
      offlineAllowed: false,
      subjectTitle: '',
    ),
    ConfiguredSource(
      id: 'legacy-direct',
      name: '手动添加的播放地址',
      kind: 'direct',
      endpoint: '',
      userId: '',
      enabled: true,
      priority: 0,
      offlineAllowed: false,
      subjectTitle: '',
    ),
  ];

  List<ConfiguredSource> _merge(List<ConfiguredSource> stored) => {
    for (final source in defaultSources) source.id: source,
    for (final source in stored) source.id: source,
  }.values.toList();

  Stream<List<ConfiguredSource>> watchSources() =>
      db.select(db.configuredSources).watch().map(_merge);

  Future<List<ConfiguredSource>> sources() async =>
      _merge(await db.select(db.configuredSources).get());

  Future<ConfiguredSource?> byId(String id) async =>
      (await sources()).where((config) => config.id == id).firstOrNull;

  Future<void> put(
    ConfiguredSource config, {
    Map<String, Object?>? secret,
  }) async {
    if (secret == null) {
      await db.into(db.configuredSources).insertOnConflictUpdate(config);
      return;
    }
    final key = 'source.${config.id}';
    final previous = await vault.read(key);
    await vault.write(key, secret);
    try {
      await db.into(db.configuredSources).insertOnConflictUpdate(config);
    } on Object {
      if (previous == null) {
        await vault.delete(key);
      } else {
        await vault.write(key, previous);
      }
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final config = await byId(id);
    if (config == null || defaultSources.any((source) => source.id == id)) {
      return;
    }
    // Disable first so a failed vault deletion never leaves a usable registration.
    await put(config.copyWith(enabled: false));
    await vault.delete('source.$id');
    await (db.delete(
      db.configuredSources,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<Map<String, dynamic>?> credentials(String id) =>
      vault.read('source.$id');

  Future<MediaLink?> linked(String id) => (db.select(
    db.mediaLinks,
  )..where((row) => row.mediaId.equals(id))).getSingleOrNull();

  Future<void> link(MediaLink link) =>
      db.into(db.mediaLinks).insertOnConflictUpdate(link);

  Future<Map<String, ResourceMatche>> matches(String episodeKey) async => {
    for (final row in await (db.select(
      db.resourceMatches,
    )..where((row) => row.episodeKey.equals(episodeKey))).get())
      row.resourceKey: row,
  };

  Future<void> recordMatch(
    String episodeKey,
    String resourceKey,
    MatchEvidence match, {
    bool confirmed = false,
  }) async {
    await db.customInsert(
      '''
      INSERT INTO resource_matches (episode_key, resource_key, score, reason, confirmed)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT (episode_key, resource_key) DO UPDATE SET
        score=excluded.score, reason=excluded.reason, confirmed=excluded.confirmed
      WHERE resource_matches.confirmed = 0 OR excluded.confirmed = 1
      ''',
      variables: [
        Variable(episodeKey),
        Variable(resourceKey),
        Variable(match.score),
        Variable(match.reason),
        Variable(confirmed),
      ],
      updates: {db.resourceMatches},
    );
  }

  Future<String?> preference(String key) async => (await (db.select(
    db.preferences,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setPreference(String key, String value) async {
    await db
        .into(db.preferences)
        .insertOnConflictUpdate(Preference(key: key, value: value));
  }

  Future<Map<String, SourceHealthRow>> health() async => {
    for (final row in await db.select(db.sourceHealthRows).get()) row.id: row,
  };

  Future<void> recordHealth(
    String id,
    SourceState state, {
    int? startup,
    int buffers = 0,
    bool playbackFailure = false,
  }) => db.transaction(() async {
    final table = db.sourceHealthRows;
    final before = await (db.select(
      table,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final priorStartup = before?.startupMs ?? 0;
    await db
        .into(table)
        .insertOnConflictUpdate(
          SourceHealthRow(
            id: id,
            state: state.name,
            successes: (before?.successes ?? 0) + (startup == null ? 0 : 1),
            failures: (before?.failures ?? 0) + (playbackFailure ? 1 : 0),
            startupMs: startup == null
                ? priorStartup
                : priorStartup == 0
                ? startup
                : ((priorStartup * 2 + startup) / 3).round(),
            buffers: ((before?.buffers ?? 0) + buffers).clamp(0, 100),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  });
}
