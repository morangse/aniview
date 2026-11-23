import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/network/bangumi_http.dart';
import '../../features/anime/anime.dart';
import 'bangumi_parser.dart';

class BangumiRepository implements AnimeRepository {
  BangumiRepository(this._http, this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final BangumiHttp _http;
  final AppDatabase _db;
  final DateTime Function() _clock;
  final _pending = <String, Future<CatalogValue<Map<String, dynamic>>>>{};
  static const _pageSize = 24;
  static const _listTtl = Duration(hours: 3);
  static const _detailTtl = Duration(hours: 12);
  static const _maxStaleness = Duration(days: 14);

  @override
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0}) {
    if (catalog == Catalog.season || catalog == Catalog.popular) {
      final now = _clock();
      final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      return _listStream(
        '/v0/search/subjects',
        offset,
        body: {
          'keyword': '',
          'sort': 'heat',
          'filter': {
            'type': [2],
            if (catalog == Catalog.season)
              'air_date': _range(
                DateTime(now.year, firstMonth),
                DateTime(now.year, firstMonth + 3),
              ),
          },
        },
      );
    }
    return _listStream(
      '/v0/subjects',
      offset,
      params: {'type': 2, 'sort': catalog == Catalog.ranking ? 'rank' : 'date'},
    );
  }

  @override
  Stream<CatalogPage> search(SearchQuery query) {
    final year = query.year;
    if (query.keyword.isEmpty && query.tag == null) {
      return _listStream(
        '/v0/subjects',
        query.offset,
        params: {'type': 2, 'sort': 'rank', 'year': ?year},
      );
    }
    return _listStream(
      '/v0/search/subjects',
      query.offset,
      body: {
        'keyword': query.keyword,
        'sort': query.keyword.isEmpty ? 'rank' : 'match',
        'filter': {
          'type': [2],
          if (query.tag != null) 'tag': [query.tag],
          if (year != null)
            'air_date': _range(DateTime(year), DateTime(year + 1)),
        },
      },
    );
  }

  Stream<CatalogPage> _listStream(
    String path,
    int offset, {
    Map<String, Object> params = const {},
    Map<String, Object>? body,
  }) async* {
    await for (final response in _cachedStream(
      path,
      {'limit': _pageSize, 'offset': offset, ...params},
      body: body,
      ttl: _listTtl,
    )) {
      final rows = _rows(response.value);
      yield CatalogPage(
        items: rows
            .whereType<Map<String, dynamic>>()
            .map(parseBangumiAnime)
            .nonNulls
            .toList(growable: false),
        nextOffset: _next(response.value, offset, rows.length, _pageSize),
        stale: response.stale,
      );
    }
  }

  Stream<CatalogValue<Map<String, dynamic>>> _cachedStream(
    String path,
    Map<String, Object> query, {
    Map<String, Object>? body,
    required Duration ttl,
  }) async* {
    final key = jsonEncode([path, query, body]);
    final now = _clock();
    final millis = now.millisecondsSinceEpoch;
    final table = _db.metadataCache;
    final row = await (_db.select(
      table,
    )..where((row) => row.key.equals(key))).getSingleOrNull();

    Map<String, dynamic>? cached;
    if (row != null && row.storedAt >= millis - _maxStaleness.inMilliseconds) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is Map<String, dynamic>) cached = decoded;
      } on FormatException {
        // A corrupt cache entry can be replaced by the next successful request.
      }
      if (cached != null) {
        yield CatalogValue(cached, stale: row.expiresAt <= millis);
        if (row.expiresAt > millis) return;
      }
    }

    try {
      yield await _networkFetch(key, path, query, body, ttl);
    } on CatalogFailure catch (error) {
      if (error.transient && cached != null) {
        return; // already yielded stale cache, stop
      }
      rethrow;
    }
  }

  @override
  Future<CatalogValue<Anime>> subject(int id) async {
    final response = await _cached(
      '/v0/subjects/$id',
      const {},
      ttl: _detailTtl,
    );
    final anime = parseBangumiAnime(response.value);
    if (anime == null || anime.id != id) {
      throw const CatalogFailure('该番剧资料暂不可用。');
    }
    return CatalogValue(anime, stale: response.stale);
  }

  @override
  Future<CatalogValue<List<Episode>>> episodes(int subjectId) async {
    const size = 200;
    final entries = <int, Episode>{};
    var stale = false;
    int? offset = 0;
    while (offset != null) {
      final response = await _cached('/v0/episodes', {
        'subject_id': subjectId,
        'limit': size,
        'offset': offset,
      }, ttl: _detailTtl);
      stale = stale || response.stale;
      final rows = _rows(response.value);
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final episode = parseBangumiEpisode(row);
        if (episode != null) entries[episode.id] = episode;
      }
      offset = _next(response.value, offset, rows.length, size);
    }
    final ordered = entries.values.toList()
      ..sort((a, b) {
        final kind = a.kind.index.compareTo(b.kind.index);
        return kind == 0 ? a.number.compareTo(b.number) : kind;
      });
    return CatalogValue(ordered, stale: stale);
  }

  Future<CatalogValue<Map<String, dynamic>>> _cached(
    String path,
    Map<String, Object> query, {
    Map<String, Object>? body,
    required Duration ttl,
  }) async {
    final key = jsonEncode([path, query, body]);
    final now = _clock();
    final millis = now.millisecondsSinceEpoch;
    final table = _db.metadataCache;
    final row = await (_db.select(
      table,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    Map<String, dynamic>? cached;
    if (row != null && row.storedAt >= millis - _maxStaleness.inMilliseconds) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is Map<String, dynamic>) cached = decoded;
      } on FormatException {
        // A corrupt cache entry can be replaced by the next successful request.
      }
      if (cached != null && row.expiresAt > millis) return CatalogValue(cached);
    }
    try {
      return await _networkFetch(key, path, query, body, ttl);
    } on CatalogFailure catch (error) {
      if (error.transient && cached != null) {
        return CatalogValue(cached, stale: true);
      }
      rethrow;
    }
  }

  Future<CatalogValue<Map<String, dynamic>>> _networkFetch(
    String key,
    String path,
    Map<String, Object> query,
    Map<String, Object>? body,
    Duration ttl,
  ) {
    return _pending.putIfAbsent(key, () async {
      try {
        final now = _clock();
        final millis = now.millisecondsSinceEpoch;
        final table = _db.metadataCache;
        final response = await _http.request(path, query: query, body: body);
        if (path.startsWith('/v0/subjects/')) {
          if (response['id'] is! int) {
            throw const CatalogFailure('Bangumi 返回的条目资料不完整。');
          }
        } else {
          _rows(response);
        }
        await _db.transaction(() async {
          await _db
              .into(table)
              .insertOnConflictUpdate(
                MetadataCacheData(
                  key: key,
                  payload: jsonEncode(response),
                  expiresAt: now.add(ttl).millisecondsSinceEpoch,
                  storedAt: millis,
                ),
              );
          await _db.customStatement(
            'DELETE FROM metadata_cache WHERE key IN '
            '(SELECT key FROM metadata_cache ORDER BY stored_at DESC LIMIT -1 OFFSET 500)',
          );
        });
        return CatalogValue(response);
      } finally {
        _pending.remove(key);
      }
    });
  }

  static List<dynamic> _rows(Map<String, dynamic> response) {
    final result = response['data'];
    if (result is List) return result;
    throw const CatalogFailure('Bangumi 返回的列表格式有误。');
  }

  static int? _next(
    Map<String, dynamic> response,
    int offset,
    int length,
    int size,
  ) {
    if (length == 0) return null;
    final total = response['total'];
    final next = offset + length;
    if (total is int) return next < total ? next : null;
    return length >= size ? next : null;
  }

  static List<String> _range(DateTime start, DateTime end) {
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-01';
    return ['>=${date(start)}', '<${date(end)}'];
  }
}
