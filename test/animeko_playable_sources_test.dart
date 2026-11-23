import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/animeko_json_source.dart';
import 'package:aniview/media/sources/catalog_subscription.dart';
import 'package:aniview/media/sources/episode_matcher.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

const _host = 'https://source.example';
const _anime = Anime(
  id: 11,
  chineseName: '测试番',
  originalName: 'テスト',
  date: '2025-01-01',
  episodeCount: 12,
);
const _episode = Episode(id: 5, number: 1, title: 'First');

final _jsonRule = <String, dynamic>{
  'baseUrl': _host,
  'headers': 'apikey: sb_publishable_fixture_only\nAuthorization: Bearer sb_publishable_fixture_only',
  'search': {
    'request': {
      'url': '/api/search',
      'method': 'POST',
      'body': '{"query":"{keyword}"}',
    },
    'selectItems': r'$[*]',
    'selectName': r'$.title',
    'selectId': r'$.id',
  },
  'subject': {
    'request': {'url': '/api/subject', 'method': 'POST', 'body': '{"id":{id}}'},
    'channelFormatId': 'grouped',
    'channelFormatGrouped': {
      'selectChannels': r'$.sources[*]',
      'selectChannelName': r'$.name',
    },
    'episodes': {
      'selectEpisodes': r'$.episodes[*]',
      'selectName': r'$.title',
      'selectId': r'$.id',
      'selectSort': r'$.episode_number',
      'selectType': r'$.kind',
      'typeMapping': 'main=MainStory\nsp=SP',
    },
  },
  'play': {
    'request': {'url': '/api/play', 'method': 'POST', 'body': '{"ep":{id}}'},
    'selectCandidates': r'$.candidates[*]',
    'selectCandidateChannel': r'$.line',
    'selectVideoUrl': r'$.url',
  },
};

const _webRule = {
  'searchUrl': '$_host/web/search?q={keyword}',
  'subjectFormatId': 'a',
  'selectorSubjectFormatA': {'selectLists': '.result a'},
  'channelFormatId': 'index-grouped',
  'selectorChannelFormatFlattened': {
    'selectEpisodeLists': '.line',
    'selectEpisodesFromList': 'a',
  },
};

String _manifest() => jsonEncode({
  'schemaVersion': 2,
  'mediaSources': [
    {
      'id': 'web',
      'factoryId': 'web-selector',
      'version': 2,
      'arguments': {'name': 'Web', 'searchConfig': _webRule},
    },
    {
      'id': 'api',
      'factoryId': 'json-api',
      'version': 1,
      'arguments': {'name': 'API', 'searchConfig': _jsonRule},
    },
  ],
});

void main() {
  test('imports and resolves Web and JSON API episode candidates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final http = createMediaHttp();
    addTearDown(db.close);
    addTearDown(http.close);
    final store = SourceStore(db, TestVault());
    final library = LocalLibrary(db);
    final registry = MediaSourceRegistry(store, library, http);
    final resolver = MediaResolver(registry, store, library);
    final requests = <String>[];
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.origin, _host);
          expect(options.followRedirects, false);
          final route = options.uri.path;
          requests.add(route);
          if (route.startsWith('/api')) {
            expect(options.method, 'POST');
            expect(options.headers['apikey'], 'sb_publishable_fixture_only');
          } else {
            expect(options.headers['apikey'], isNull);
          }
          final text = switch (route) {
            '/subscription.json' => _manifest(),
            '/api/search' => '[{"id":9,"title":"测试番","title_original":"テスト","release_year":2025,"total_episodes":12}]',
            '/api/subject' =>
              '{"sources":[{"name":"主线","episodes":['
                  '{"id":71,"episode_number":1,"kind":"main"},'
                  '{"id":72,"episode_number":2,"kind":"main"}]}]}',
            '/api/play' =>
              '{"candidates":[{"line":"其他","url":"/wrong.mp4"},'
                  '{"line":"主线","url":"https://cdn.example/one.m3u8?signature=fixture"}]}',
            '/web/search' => '<main class="result"><a data-bangumi-subject="11" href="/web/title">测试番</a></main>',
            '/web/title' =>
              '<div class="line">'
                  '<a data-bangumi-episode="5" href="/web/watch">第 1 集</a>'
                  '<a href="/web/wrong">第 2 集</a></div>',
            '/web/watch' =>
              '<video><source src="/one.mp4" type="video/mp4"></video>',
            _ => throw StateError('Unexpected $route'),
          };
          if (route == '/api/search') {
            expect(jsonDecode(options.data as String), {'query': '测试番'});
          }
          if (route == '/api/play') {
            expect(jsonDecode(options.data as String), {'ep': 71});
          }
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromString(text, 200),
            ),
          );
        },
      ),
    );

    final sub = await CatalogSubscription.read(
      http,
      'source.example/subscription.json',
    );
    expect(requests, ['/subscription.json']);
    expect(sub.members.map((member) => member.kind), [
      SourceKind.animekoWeb,
      SourceKind.animekoJson,
    ]);
    expect(await sub.importSelected(store, {'web', 'api'}), (
      added: 2,
      skipped: 0,
    ));
    const target = MediaSearchRequest(anime: _anime, episode: _episode);
    final result = await resolver.find(target);
    expect(result.diagnostics, isEmpty);
    expect(result.offers, hasLength(2));
    final mediaUrls = <Uri>[];
    for (final ranked in result.offers) {
      expect(PlaybackSession.canSelectAutomatically(ranked), true);
      expect(ranked.offer.number, 1);
      final candidate = await resolver.save(target, ranked.offer);
      final access = await resolver.access(candidate);
      expect(access.restrictOrigin, true);
      expect(access.headers, isEmpty);
      mediaUrls.add(access.uri);
    }
    expect(
      mediaUrls.map((entry) => entry.path),
      containsAll(['/one.mp4', '/one.m3u8']),
    );
    expect(requests, isNot(contains('/web/wrong')));
  });

  test('year mismatch and absent metadata still require confirmation', () {
    const matcher = EpisodeMatcher();
    const target = MediaSearchRequest(anime: _anime, episode: _episode);
    const wrongYear = SourceOffer(
      sourceId: 'web',
      resourceId: 'first',
      label: 'first',
      seriesTitle: '测试番',
      seriesOriginalTitle: 'テスト',
      seriesYear: 2027,
      seriesEpisodeCount: 12,
      numberedWithinSubject: true,
      number: 1,
      kind: EpisodeKind.regular,
    );
    expect(matcher.evaluate(target, wrongYear).verified, false);
  });

  test('rejects private API credentials and a cross-origin API template', () {
    expect(
      () => AnimekoJsonRule.parse({..._jsonRule, 'headers': 'Cookie: private'}),
      throwsFormatException,
    );
    expect(
      () => AnimekoJsonRule.parse({
        ..._jsonRule,
        'search': {
          ..._jsonRule['search'] as Map,
          'request': {'url': 'https://other.example/search'},
        },
      }),
      throwsFormatException,
    );
  });
}
