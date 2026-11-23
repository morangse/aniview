import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  for (final kind in ['jellyfin', 'emby']) {
    test(
      '$kind verifies explicit episode IDs and resolves an authorized direct stream',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final dio = createMediaHttp();
        addTearDown(db.close);
        addTearDown(dio.close);
        final store = SourceStore(db, TestVault());
        final library = LocalLibrary(db);
        final registry = MediaSourceRegistry(store, library, dio);
        final resolver = MediaResolver(registry, store, library);
        final prefix = kind == 'emby' ? '/emby' : '';
        final config = ConfiguredSource(
          id: 'server-id',
          kind: kind,
          name: 'Authorized test server',
          endpoint: 'http://192.168.1.5:8096$prefix',
          userId: '',
          enabled: true,
          priority: 2,
          offlineAllowed: false,
          subjectTitle: '',
        );
        DioException? unhandled;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final uri = options.uri;
              final route = uri.path.substring(prefix.length);
              final authorization = options.headers['Authorization'] as String;
              expect(
                authorization.startsWith(
                  kind == 'emby' ? 'Emby ' : 'MediaBrowser ',
                ),
                true,
              );
              expect(uri.toString(), isNot(contains('dummy-access-token')));
              if (!route.endsWith('AuthenticateByName')) {
                if (kind == 'emby') {
                  expect(options.headers['X-Emby-Token'], 'dummy-access-token');
                  expect(authorization, contains('UserId="user-id"'));
                } else {
                  expect(authorization, contains('Token="dummy-access-token"'));
                }
              }
              if (route == '/Shows/series-id/Episodes') {
                expect(
                  uri.queryParameters['Fields'],
                  'MediaStreams,ProviderIds',
                );
                expect(uri.queryParameters['Season'], '2');
              }
              final Map<String, Object?>? data = switch (route) {
                '/Users/AuthenticateByName' => {
                  'User': {'Id': 'user-id'},
                  'AccessToken': 'dummy-access-token',
                },
                '/Users/user-id' => {'Id': 'user-id'},
                '/Items' => {
                  'Items': [
                    {
                      'Id': 'series-id',
                      'Name': 'Authorized Series Season 2',
                      'ProviderIds': {'Bangumi': '24'},
                    },
                  ],
                },
                '/Shows/series-id/Episodes' => {
                  'Items': [
                    {
                      'Id': 'episode-id',
                      'Name': 'Episode 3',
                      'IndexNumber': 3,
                      'ParentIndexNumber': 2,
                      'ProviderIds': {'Bangumi': '30'},
                      'MediaStreams': [
                        {'Type': 'Video', 'Width': 1920},
                        {'Type': 'Audio', 'Language': 'jpn'},
                      ],
                    },
                    {
                      'Id': 'unidentified-episode',
                      'Name': 'Episode 3 without Bangumi metadata',
                      'IndexNumber': 3,
                      'ParentIndexNumber': 2,
                      'ProviderIds': {'Tvdb': '30'},
                    },
                    {
                      'Id': 'different-episode',
                      'Name': 'Episode 3 of a different entry',
                      'IndexNumber': 3,
                      'ParentIndexNumber': 2,
                      'ProviderIds': {'Bangumi': '31'},
                    },
                  ],
                },
                '/Items/episode-id/PlaybackInfo' => {
                  'MediaSources': [
                    {
                      'Id': 'file-id',
                      'SupportsDirectPlay': true,
                      'IsRemote': false,
                    },
                  ],
                },
                _ => null,
              };
              if (data == null) {
                unhandled = DioException(requestOptions: options);
                handler.reject(unhandled!);
              } else {
                handler.resolve(Response(requestOptions: options, data: data));
              }
            },
          ),
        );
        final credentials = await (registry.adapter(config) as JellyfinSource)
            .login('user', 'fake-qa');
        await store.put(
          config.copyWith(userId: credentials.userId),
          secret: {'token': credentials.token},
        );
        final server = await registry.enabledAdapter(config.id);
        await server.testConnection();
        final result = await resolver.find(
          const MediaSearchRequest(
            anime: Anime(id: 24, originalName: 'Authorized Series Season 2'),
            episode: Episode(id: 30, number: 3, title: 'episode'),
          ),
        );
        expect(result.diagnostics, isEmpty);
        expect(result.offers.map((entry) => entry.offer.resourceId), [
          'episode-id',
          'unidentified-episode',
        ]);
        final verified = result.offers.first;
        final match = verified.offer;
        expect(verified.match.verified, true);
        expect(result.offers.last.offer.episodeId, isNull);
        expect(result.offers.last.match.verified, false);
        expect(match.season, 2);
        expect(match.subjectId, 24);
        expect(match.episodeId, 30);
        expect(match.width, 1920);
        expect(match.audioLanguages, ['jpn']);
        final playable = await server.resolve(match.resourceId);
        expect(playable.uri.path, '$prefix/Videos/episode-id/stream');
        expect(playable.uri.queryParameters, {
          'Static': 'true',
          'MediaSourceId': 'file-id',
        });
        expect(unhandled, isNull);
      },
    );
  }
}
