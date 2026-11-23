import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/animeko_rss_source.dart';
import 'package:aniview/media/sources/catalog_subscription.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

const _manifest = '''
{
  "schemaVersion": 2,
  "mediaSources": [
    {"id": "videos", "factoryId": "rss", "version": 1, "arguments": {
      "name": "样例视频", "searchConfig": {
        "searchUrl": "https://video.example/search?q={keyword}"
      }
    }},
    {"id": "selector", "factoryId": "web-selector", "version": 2,
      "arguments": {"name": "样例网页"}},
    {"id": "api", "factoryId": "json-api", "version": 1,
      "arguments": {"name": "样例 API"}},
    {"id": "invalid", "factoryId": "rss", "version": 1, "arguments": {
      "name": "样例无效地址", "searchConfig": {
        "searchUrl": "https://{keyword}.example/feed"
      }
    }}
  ]
}
''';

const _title = '番剧 & "字幕"';
const _request = MediaSearchRequest(
  anime: Anime(id: 42, originalName: _title),
  episode: Episode(id: 4201, number: 1, title: '首集'),
);

void main() {
  test('keeps the keyword inside plain and JSON query values', () {
    final address = AnimekoRssAddress.parse(
      'https://video.example/rss?q={keyword}&q=stable&filter={"include":["{keyword}"]}',
    );
    final uri = address.forTitle(_title);
    expect(uri.origin, 'https://video.example');
    expect(uri.path, '/rss');
    expect(uri.queryParametersAll['q'], [_title, 'stable']);
    expect(jsonDecode(uri.queryParameters['filter']!), {
      'include': [_title],
    });
    for (final input in [
      'https://{keyword}.example/rss',
      'https://{keyword}:password@video.example/rss',
      'https://@video.example/rss',
      'https://video.example/{keyword}',
      'https://video.example/rss?{keyword}=value',
      'https://video.example/rss#{keyword}',
    ]) {
      expect(() => AnimekoRssAddress.parse(input), throwsFormatException);
    }
  });

  test('shows incompatible Animeko members without enabling them', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = SourceStore(db, TestVault());
    final subscription = CatalogSubscription.parse(
      _manifest,
      Uri.parse('https://subs.example/list.json'),
    );
    expect(subscription.members.map((source) => source.canImport), [
      true,
      false,
      false,
      false,
    ]);
    final ids = subscription.members.map((source) => source.id).toSet();
    expect(await subscription.importSelected(store, ids), (
      added: 1,
      skipped: 0,
    ));
    final imported = (await store.sources()).last;
    expect(imported.kind, SourceKind.animekoRss.name);
    expect(imported.endpoint, 'https://video.example/search?q={keyword}');
    await store.put(imported.copyWith(enabled: false));
    expect(await subscription.importSelected(store, ids), (
      added: 0,
      skipped: 1,
    ));
    expect((await store.byId(imported.id))!.enabled, false);
  });

  test('queries and resolves an exact episode through the existing player pipeline', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dio = createMediaHttp();
    addTearDown(db.close);
    addTearDown(dio.close);
    final store = SourceStore(db, TestVault());
    final library = LocalLibrary(db);
    final registry = MediaSourceRegistry(store, library, dio);
    final resolver = MediaResolver(registry, store, library);
    final subscription = CatalogSubscription.parse(
      _manifest,
      Uri.parse('https://subs.example/list.json'),
    );
    await subscription.importSelected(store, {'videos'});
    var token = 'first';
    var requested = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requested++;
          expect(options.uri.origin, 'https://video.example');
          expect(options.uri.path, '/search');
          expect(options.uri.queryParameters['q'], _title);
          expect(options.followRedirects, false);
          expect(options.headers['authorization'], isNull);
          final xml =
              '''
<rss version="2.0" xmlns:av="urn:aniview:catalog:v1"><channel>
<item><guid>https://video.example/episode/1</guid><title>样例首集</title>
<av:subjectId>42</av:subjectId><av:episodeId>4201</av:episodeId>
<enclosure url="/episode.m3u8?signature=$token" type="application/vnd.apple.mpegurl"/></item>
<item><guid>episode-2</guid><title>第二集</title>
<av:subjectId>42</av:subjectId><av:episodeId>4202</av:episodeId>
<enclosure url="/episode-2.mp4" type="video/mp4"/></item>
<item><guid>unsupported</guid><title>种子</title>
<enclosure url="/archive.torrent" type="application/x-bittorrent"/></item>
<item><guid>external</guid><title>外部视频</title>
<enclosure url="https://external.example/episode.mp4" type="video/mp4"/></item>
</channel></rss>''';
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromString(xml, 200),
            ),
          );
        },
      ),
    );
    final ranked = (await resolver.find(_request)).offers.single;
    expect(ranked.offer.episodeId, 4201);
    expect(PlaybackSession.canSelectAutomatically(ranked), true);
    final candidate = await resolver.save(_request, ranked.offer);
    token = 'fresh';
    final access = await resolver.access(candidate);
    expect(access.uri.queryParameters['signature'], 'fresh');
    expect(access.restrictOrigin, true);
    expect(requested, 2);
  });
}
