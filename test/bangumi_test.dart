import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/network/bangumi_http.dart';
import 'package:aniview/data/bangumi/bangumi_parser.dart';
import 'package:aniview/data/bangumi/bangumi_repository.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const subjectJson = {
  'id': 42,
  'type': 2,
  'name': '試験アニメ',
  'name_cn': '测试番剧',
  'summary': '  测试简介  ',
  'platform': 'TV',
  'date': '2026-10-03',
  'eps': 12,
  'total_episodes': 10,
  'rating': {'score': 8.2, 'total': 3},
  'images': {
    'common': '//lain.bgm.tv/test.jpg',
    'large': 'https://lain.bgm.tv/poster.jpg',
  },
  'tags': [
    {'name': '奇幻'},
    {'name': '奇幻'},
    {'name': ''},
  ],
};

void main() {
  test('parses a full subject and maintains a persistable representation', () {
    final anime = parseBangumiAnime(subjectJson)!;
    expect(anime.title, '测试番剧');
    expect(anime.originalName, '試験アニメ');
    expect(anime.summary, '测试简介');
    expect(anime.year, '2026');
    expect(anime.episodeCount, 12);
    expect(anime.score, 8.2);
    expect(anime.cover.toString(), 'https://lain.bgm.tv/test.jpg');
    expect(anime.tags, ['奇幻']);
    expect(Anime.fromJson(anime.toJson()).toJson(), anime.toJson());
  });

  test('lightweight search rows fall back to original names and omit missing fields', () {
    final anime = parseBangumiAnime({
      'id': 17,
      'type': 2,
      'name': '原題',
      'date': null,
      'images': {'large': 'ftp://example.test/a'},
    })!;
    expect(anime.title, '原題');
    expect(anime.poster, isNull);
    expect(anime.score, isNull);
    expect(Anime.fromJson(anime.toJson()).cover, isNull);
    expect(parseBangumiAnime({...subjectJson, 'type': 1}), isNull);
    expect(parseBangumiAnime({...subjectJson, 'nsfw': true}), isNull);
    expect(parseBangumiAnime({...subjectJson, 'id': null}), isNull);
    expect(
      parseBangumiAnime({
        ...subjectJson,
        'images': {'large': 'https://fakebgm.tv/p.png'},
      })!.poster,
      isNull,
    );
  });

  test('episode sort retains decimal specials and localized fallback', () {
    final episode = parseBangumiEpisode({
      'id': 7,
      'sort': 5.5,
      'name': '残響',
      'name_cn': '',
      'airdate': '2026-11-18',
      'duration': '00:24:00',
    })!;
    expect(episode.label, '第 5.5 集');
    expect(episode.title, '残響');
    expect(episode.airDate, '2026-11-18');
    expect(episode.runningTime, '00:24:00');
    expect(parseBangumiEpisode({'id': 7, 'sort': '10'}), isNull);
  });

  test(
    'search sends official type, tag, date and pagination and caches by query',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = BangumiHttp.createClient();
      addTearDown(dio.close);
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'total': 30,
                  'data': [subjectJson],
                },
              ),
            );
          },
        ),
      );
      final repo = BangumiRepository(BangumiHttp(dio), db);
      const query = (keyword: '试验', tag: '奇幻', year: 2026, offset: 24);
      final pages = await Future.wait([repo.search(query).first, repo.search(query).first]);
      expect(pages.first.items.single.id, 42);
      expect(pages.first.nextOffset, 25);
      expect((await repo.search(query).first).items.single.title, '测试番剧');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v0/search/subjects');
      expect(request.headers['User-Agent'], BangumiHttp.userAgent);
      expect(request.queryParameters, {'limit': 24, 'offset': 24});
      expect(request.data, {
        'keyword': '试验',
        'sort': 'match',
        'filter': {
          'type': [2],
          'tag': ['奇幻'],
          'air_date': ['>=2026-01-01', '<2027-01-01'],
        },
      });
    },
  );

  test(
    'transient requests retry once, then return explicitly stale catalog data',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = BangumiHttp.createClient();
      addTearDown(dio.close);
      var attempts = 0;
      var upstreamError = 0;
      var now = DateTime(2026, 11, 18);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            attempts++;
            if (upstreamError != 0) {
              handler.reject(
                DioException.badResponse(
                  statusCode: upstreamError,
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: upstreamError,
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response(requestOptions: options, data: subjectJson),
              );
            }
          },
        ),
      );
      final repo = BangumiRepository(BangumiHttp(dio), db, clock: () => now);
      expect((await repo.subject(42)).stale, false);
      upstreamError = 503;
      now = now.add(const Duration(hours: 13));
      final cached = await repo.subject(42);
      expect(cached.stale, true);
      expect(cached.value.title, '测试番剧');
      expect(attempts, 3);
      upstreamError = 429;
      expect((await repo.subject(42)).stale, true);
      expect(attempts, 4);
      upstreamError = 404;
      await expectLater(repo.subject(42), throwsA(isA<CatalogFailure>()));
      expect(attempts, 5);
    },
  );

  test(
    'episodes use documented pagination and preserve ascending episode order',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = BangumiHttp.createClient();
      addTearDown(dio.close);
      final offsets = <int>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/v0/episodes');
            expect(options.queryParameters['subject_id'], 42);
            expect(options.queryParameters.containsKey('type'), false);
            final offset = options.queryParameters['offset'] as int;
            offsets.add(offset);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'total': 3,
                  'data': offset == 0
                      ? [
                          {'id': 11, 'sort': 3},
                          {'id': 10, 'sort': 2},
                        ]
                      : [
                          {'id': 9, 'sort': 1},
                        ],
                },
              ),
            );
          },
        ),
      );
      final repo = BangumiRepository(BangumiHttp(dio), db);
      expect((await repo.episodes(42)).value.map((entry) => entry.id), [
        9,
        10,
        11,
      ]);
      expect(offsets, [0, 2]);
    },
  );
}
