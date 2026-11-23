import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/core/network/bangumi_http.dart';
import 'package:aniview/data/bangumi/bangumi_sync.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/media.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  test(
    'sync failure leaves bookmarks intact and never logs the token',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final library = LocalLibrary(db);
      final dio = BangumiHttp.createClient();
      final secrets = TestVault();
      addTearDown(db.close);
      addTearDown(dio.close);
      const token = 'test-auth-only-12345678';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.toString(), isNot(contains(token)));
            expect(options.headers['Authorization'], 'Bearer $token');
            if (options.path == '/v0/me') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'username': 'tester', 'nickname': 'Test'},
                ),
              );
            } else {
              handler.reject(
                DioException.badResponse(
                  statusCode: 429,
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 429,
                  ),
                ),
              );
            }
          },
        ),
      );
      final sync = BangumiSyncService(
        library,
        secrets,
        BangumiSyncApi(dio, interval: Duration.zero),
        BangumiOAuthBridge(dio, null),
      );
      const item = Anime(id: 11, originalName: 'test');
      await library.setFavorite(item, true);
      expect((await sync.bindPersonalToken(token)).username, 'tester');
      await expectLater(
        sync.sync(pushFavorites: true, pushWatched: true),
        throwsA(isA<CatalogFailure>()),
      );
      expect((await library.watchFavorites().first).single.id, 11);
      final error = (await db.select(db.syncSnapshots).get()).single;
      expect(error.value, contains('限制'));
      expect(error.value, isNot(contains(token)));
    },
  );

  test('sync respects local removals, remote drops and never uploads video seconds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final library = LocalLibrary(db);
    final dio = BangumiHttp.createClient();
    addTearDown(db.close);
    addTearDown(dio.close);
    final writes = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final Map<String, Object?>? result;
          if (options.method == 'PUT') {
            writes.add(options);
            result = null;
          } else if (options.path == '/v0/me') {
            result = {'username': 'tester'};
          } else if (options.path.endsWith('/collections')) {
            result = {
              'total': 3,
              'data': [
                {
                  'subject_id': 10,
                  'type': 3,
                  'subject': {'name': 'In progress'},
                },
                {
                  'subject_id': 11,
                  'type': 3,
                  'subject': {'name': 'Removed'},
                },
                {
                  'subject_id': 12,
                  'type': 5,
                  'subject': {'name': 'Dropped'},
                },
              ],
            };
          } else {
            result = {'type': 1};
          }
          handler.resolve(Response(requestOptions: options, data: result));
        },
      ),
    );
    final sync = BangumiSyncService(
      library,
      TestVault(),
      BangumiSyncApi(dio, interval: Duration.zero),
      BangumiOAuthBridge(dio, null),
    );
    await sync.bindPersonalToken('test-auth-value-only');
    await library.setFavorite(
      const Anime(id: 11, originalName: 'Removed'),
      false,
    );
    for (final (subject, episode, complete) in [
      (10, 22, true),
      (10, 23, false),
      (12, 24, true),
    ]) {
      final media = MediaCandidate.create(
        uri: Uri.parse('https://example.invalid/owned.mp4'),
        kind: MediaKind.direct,
        sourceName: 'test',
        request: MediaRequest(
          anime: Anime(id: subject, originalName: 'test'),
          episode: Episode(id: episode, number: 1, title: 'test'),
        ),
      );
      await library.addMedia(media);
      await library.save(
        media.id,
        WatchProgress(
          position: const Duration(seconds: 18),
          duration: const Duration(seconds: 20),
          completed: complete,
          updatedAt: DateTime.now(),
        ),
      );
    }
    final report = await sync.sync(pushFavorites: false, pushWatched: true);
    expect(report, contains('保留冲突 1 项'));
    expect(
      (await library.watchFavorites().first).map((entry) => entry.id).toSet(),
      {10, 12},
    );
    expect(writes.single.path, '/v0/users/-/collections/-/episodes/22');
    expect(writes.single.data, {'type': 2});
  });

  test('sync imports 5-state collections and enforces local-first on dirty conflicts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final library = LocalLibrary(db);
    final dio = BangumiHttp.createClient();
    addTearDown(db.close);
    addTearDown(dio.close);
    final posts = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') {
            posts.add(options);
            handler.resolve(Response(requestOptions: options, data: null));
            return;
          }
          if (options.path == '/v0/me') {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'username': 'tester'},
              ),
            );
            return;
          }
          if (options.path.endsWith('/collections')) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'total': 3,
                  'data': [
                    {
                      'subject_id': 101,
                      'type': 3,
                      'rate': 5,
                      'comment': 'remote-comment',
                      'subject': {'name': 'Dirty Local'},
                    },
                    {
                      'subject_id': 102,
                      'type': 2,
                      'rate': 8,
                      'comment': 'remote-updated',
                      'subject': {'name': 'Clean Local'},
                    },
                    {
                      'subject_id': 103,
                      'type': 4,
                      'rate': 6,
                      'comment': 'hold',
                      'subject': {'name': 'Remote Only'},
                    },
                  ],
                },
              ),
            );
            return;
          }
          handler.resolve(Response(requestOptions: options, data: null));
        },
      ),
    );

    final sync = BangumiSyncService(
      library,
      TestVault(),
      BangumiSyncApi(dio, interval: Duration.zero),
      BangumiOAuthBridge(dio, null),
    );
    await sync.bindPersonalToken('test-auth-value-only');
    await library.setCollection(
      const Anime(id: 101, originalName: 'Dirty Local'),
      CollectionStatus.collected,
      rating: 9,
      comment: 'local-comment',
      markDirty: true,
    );
    await library.setCollection(
      const Anime(id: 102, originalName: 'Clean Local'),
      CollectionStatus.doing,
      rating: 7,
      comment: 'old',
      markDirty: false,
    );

    final pullReport = await sync.sync(pushFavorites: false, pushWatched: false);
    expect(pullReport, contains('导入 1 部'));
    expect(pullReport, contains('保留冲突 1 项'));

    var entries = {
      for (final e in await library.watchFavoriteEntries().first) e.anime.id: e,
    };
    expect(entries[101]!.status, CollectionStatus.collected);
    expect(entries[101]!.rating, 9);
    expect(entries[101]!.comment, 'local-comment');
    expect(entries[101]!.dirty, true);

    expect(entries[102]!.status, CollectionStatus.collected);
    expect(entries[102]!.rating, 8);
    expect(entries[102]!.comment, 'remote-updated');
    expect(entries[102]!.dirty, false);

    expect(entries[103]!.status, CollectionStatus.onHold);
    expect(entries[103]!.rating, 6);
    expect(entries[103]!.dirty, false);

    final pushReport = await sync.sync(pushFavorites: true, pushWatched: false);
    expect(pushReport, contains('新增远端收藏 1 部'));
    expect(posts, hasLength(1));
    expect(posts.single.path, '/v0/users/-/collections/101');
    expect(posts.single.data, {
      'type': 2,
      'private': true,
      'rate': 9,
      'comment': 'local-comment',
    });

    entries = {
      for (final e in await library.watchFavoriteEntries().first) e.anime.id: e,
    };
    expect(entries[101]!.dirty, false);
  });
}
