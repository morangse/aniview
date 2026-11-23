import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/catalog_source.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

const _request = MediaSearchRequest(
  anime: Anime(id: 12, originalName: 'Example series'),
  episode: Episode(id: 541, number: 1, title: 'First episode'),
);

void main() {
  test(
    'catalog playback persists episode identity and refreshes signed URLs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dio = createMediaHttp();
      addTearDown(db.close);
      addTearDown(dio.close);
      final store = SourceStore(db, TestVault());
      final library = LocalLibrary(db);
      final registry = MediaSourceRegistry(store, library, dio);
      final resolver = MediaResolver(registry, store, library);
      await store.put(
        const ConfiguredSource(
          id: 'owned-catalog',
          name: 'Owned catalog',
          kind: 'jsonFeed',
          endpoint: 'https://library.example/catalog',
          userId: '',
          enabled: true,
          priority: 5,
          offlineAllowed: false,
          subjectTitle: '',
        ),
        secret: {
          'headers': {'authorization': 'Bearer test-key'},
        },
      );
      var token = 'one';
      var episode = 541;
      final requests = <Uri>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.uri);
            expect(options.headers['authorization'], 'Bearer test-key');
            expect(options.followRedirects, false);
            expect(options.validateStatus(302), false);
            final body = jsonEncode({
              'schemaVersion': 1,
              'resources': [
                {
                  'id': 'first',
                  'title': 'First',
                  'bangumiSubjectId': 12,
                  'bangumiEpisodeId': episode,
                  'url': '/view/first?signature=$token',
                  'mimeType': 'video/mp4',
                },
                {
                  'id': 'second',
                  'title': 'Second',
                  'bangumiSubjectId': 12,
                  'bangumiEpisodeId': 999,
                  'url': '/second.mp4',
                },
                {
                  'id': 'foreign',
                  'title': 'Foreign',
                  'bangumiSubjectId': 12,
                  'bangumiEpisodeId': 541,
                  'url': 'https://foreign.example/episode.mp4',
                },
              ],
            });
            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                data: ResponseBody.fromString(body, 200),
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final ranked = (await resolver.find(_request)).offers.single;
      expect(PlaybackSession.canSelectAutomatically(ranked), true);
      final candidate = await resolver.save(_request, ranked.offer);
      final link = await store.linked(candidate.id);
      expect(link?.resourceId, hasLength(64));
      expect(candidate.uri.scheme, 'aniview');
      token = 'two';
      final access = await resolver.access(candidate);
      expect(
        access.uri,
        Uri.parse('https://library.example/view/first?signature=two'),
      );
      expect(access.headers['authorization'], 'Bearer test-key');
      expect(access.restrictOrigin, true);
      episode = 542;
      await expectLater(
        resolver.access(candidate),
        throwsA(isA<SourceIssue>()),
      );
      expect(
        requests,
        List.filled(3, Uri.parse('https://library.example/catalog')),
      );
    },
  );

  test('catalog endpoints permit HTTPS and configured LAN paths only', () {
    expect(
      parseCatalogEndpoint('https://library.example/feed/').path,
      '/feed/',
    );
    expect(parseCatalogEndpoint('http://192.168.0.2/rss').scheme, 'http');
    for (final address in [
      'http://library.example/feed',
      'https://library.example/feed?secret=value',
      'https://user:password@library.example/feed',
      'https://@library.example/feed',
      'https://library.example/feed#fragment',
    ]) {
      expect(() => parseCatalogEndpoint(address), throwsFormatException);
    }
  });
}
