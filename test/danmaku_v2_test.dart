import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/overlays/danmaku_client.dart';
import 'package:aniview/media/overlays/danmaku_layout.dart';
import 'package:aniview/media/overlays/media_overlays.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  test('parses Dandanplay comments JSON and round-trips encodeJson', () {
    const dandanJson =
        '{"count":2,"comments":[{"cid":1,"p":"12.5,1,16711680,123","m":"高能预警"},{"cid":2,"p":"14,5,65280","m":"顶部绿字"}]}';
    final parsed = DanmakuTrack.parse(dandanJson, 'ep1.json');
    expect(parsed.items, hasLength(2));
    expect(parsed.items[0].start, 12500);
    expect(parsed.items[0].mode, DanmakuMode.scroll);
    expect(parsed.items[0].color, 0xFFFF0000);
    expect(parsed.items[0].text, '高能预警');
    expect(parsed.items[1].mode, DanmakuMode.top);
    expect(parsed.items[1].color, 0xFF00FF00);

    final encoded = DanmakuTrack.encodeJson(parsed.items);
    final reparsed = DanmakuTrack.parse(encoded, 'roundtrip.json');
    expect(reparsed.items, hasLength(2));
    expect(reparsed.items[0].color, 0xFFFF0000);
    expect(reparsed.items[1].mode, DanmakuMode.top);
  });

  test('OverlaySettings and DanmakuLayoutEngine filter modes and adjust area ratio', () {
    final settings = OverlaySettings.fromJson({
      'danmakuArea': 0.25,
      'danmakuShowScroll': false,
      'danmakuShowTop': true,
      'danmakuShowBottom': false,
      'danmakuShowColor': false,
    });
    expect(settings.danmakuArea, 0.25);
    expect(settings.danmakuShowScroll, false);
    expect(settings.danmakuShowTop, true);
    expect(settings.danmakuShowBottom, false);
    expect(settings.danmakuShowColor, false);

    final track = DanmakuTrack(const [
      DanmakuItem(1000, DanmakuMode.scroll, 'scroll-1'),
      DanmakuItem(1000, DanmakuMode.top, 'top-1'),
      DanmakuItem(1000, DanmakuMode.bottom, 'bot-1'),
    ]);
    final engine = DanmakuLayoutEngine();
    final topOnly = engine.layout(
      track: track,
      ms: 1200,
      lifeMs: 6500,
      limit: 24,
      blocked: const [],
      viewportWidth: 800,
      viewportHeight: 400,
      fontSize: 16,
      measureWidth: (item) => item.text.length * 14.0,
      areaRatio: 0.25,
      showScroll: false,
      showTop: true,
      showBottom: false,
    );
    expect(topOnly.map((e) => e.item.text).toList(), ['top-1']);
  });

  test('DanmakuClient searches compatible protocol endpoints and fetches comments/direct URLs without AppId', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.headers.containsKey('X-AppId'), false);
          expect(options.headers.containsKey('X-Signature'), false);
          if (options.uri.path.endsWith('/api/v2/search/episodes')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'animes': [
                    {
                      'animeTitle': '葬送的芙莉莲',
                      'episodes': [
                        {'episodeId': 18580001, 'episodeTitle': '第1话 冒险的终点'},
                      ],
                    },
                  ],
                },
              ),
            );
            return;
          }
          if (options.uri.path.endsWith('/api/v2/comment/18580001')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode({
                  'count': 1,
                  'comments': [
                    {'cid': 1, 'p': '5.0,1,16777215', 'm': '名场面'},
                  ],
                }),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: '<i><d p="3,1,25,16777215">XML弹幕</d></i>',
            ),
          );
        },
      ),
    );
    addTearDown(dio.close);

    final client = DanmakuClient(dio);
    final episodes = await client.searchEpisodes(
      'https://danmaku.example',
      anime: '葬送的芙莉莲',
      episode: '第1话',
    );
    expect(episodes, hasLength(1));
    expect(episodes.single.episodeId, 18580001);

    final comments = await client.fetchComments('https://danmaku.example', 18580001);
    expect(comments.count, 1);

    final xml = await client.fetchDirectUrl('https://danmaku.example/raw.xml');
    expect(xml.name, 'raw.xml');
    expect(xml.count, 1);
  });

  test('OverlayStore appends local danmaku and LocalLibrary stores danmaku endpoint', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final library = LocalLibrary(db);
    await library.setDanmakuEndpoint('https://danmaku.example');
    expect(await library.watchDanmakuEndpoint().first, 'https://danmaku.example');
    await library.setDanmakuEndpoint(null);
    expect(await library.watchDanmakuEndpoint().first, isNull);

    final store = OverlayStore(SourceStore(db, TestVault()));
    final media = MediaCandidate(
      id: 'dm-append-1',
      uri: Uri.parse('https://media.example/video.mp4'),
      kind: MediaKind.direct,
      title: 'Append Test',
      sourceName: 'ep1.mp4',
    );
    final first = await store.appendLocalDanmaku(
      media,
      const DanmakuItem(5000, DanmakuMode.scroll, '第一条弹幕', color: 0xFFFF0000),
    );
    expect(first.name, '本地弹幕.json');
    await store.save(media, {'danmakuId': first.id, 'danmakuEnabled': true});

    final xmlRow = await store.add(
      media,
      'danmaku',
      'origin.xml',
      utf8.encode('<i><d p="2,1,25,16777215">原弹幕</d></i>'),
    );
    final merged = await store.appendLocalDanmaku(
      media,
      const DanmakuItem(8000, DanmakuMode.top, '追加弹幕', color: 0xFF00FF00),
      currentDanmakuId: xmlRow.id,
    );
    expect(merged.name, 'origin.xml.json');
    await store.save(media, {'danmakuId': merged.id, 'danmakuEnabled': true});
    final bundle = await store.load(media);
    expect(bundle.danmaku?.items.map((e) => e.text).toList(), ['原弹幕', '追加弹幕']);
  });

  test('parses mode 0 danmaku as scroll, suggests search keyword, prioritizes current episode, and describes HTTP errors', () {
    const mode0Json =
        '{"count":1,"comments":[{"cid":1,"p":"0.00,0,16777215,[renren]","m":"零号模式弹幕"}]}';
    final parsed = DanmakuTrack.parse(mode0Json, 'renren.json');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.single.mode, DanmakuMode.scroll);
    expect(parsed.items.single.text, '零号模式弹幕');

    expect(
      DanmakuClient.suggestSearchKeyword('钢之炼金术师 FULLMETAL ALCHEMIST'),
      '钢之炼金术师',
    );
    expect(
      DanmakuClient.suggestSearchKeyword('[LoliHouse] 葬送的芙莉莲 / Sousou no Frieren'),
      '葬送的芙莉莲',
    );
    expect(DanmakuClient.suggestSearchKeyword('DAN DA DAN'), 'DAN DA DAN');

    final reordered = DanmakuClient.prioritizeMatches(const [
      DanmakuEpisodeMatch(episodeId: 1, animeTitle: 'A', episodeTitle: '第01集'),
      DanmakuEpisodeMatch(episodeId: 2, animeTitle: 'A', episodeTitle: '第02集'),
      DanmakuEpisodeMatch(episodeId: 10, animeTitle: 'A', episodeTitle: '第10集'),
      DanmakuEpisodeMatch(episodeId: 12, animeTitle: 'A', episodeTitle: '第12集'),
    ], episodeLabel: '第 12 集');
    expect(reordered.first.episodeId, 12);

    final req = RequestOptions(path: '/api/v2/search/episodes');
    final err403 = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: req,
        statusCode: 403,
        headers: Headers.fromMap({
          'x-error-message': ['Missing Authentication Headers'],
        }),
      ),
    );
    final msg403 = DanmakuClient.describeError(err403, fallback: 'fail');
    expect(msg403, contains('403'));
    expect(msg403, contains('Missing Authentication Headers'));
    expect(msg403, contains('api.dandanplay.net'));

    final errTimeout = DioException(
      requestOptions: req,
      type: DioExceptionType.receiveTimeout,
    );
    expect(
      DanmakuClient.describeError(errTimeout, fallback: 'fail'),
      contains('超时'),
    );
  });

  test('LocalLibrary manages multiple danmaku endpoints cleanly', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final library = LocalLibrary(db);

    await db
        .into(db.preferences)
        .insert(
          const Preference(
            key: 'danmaku.endpoint',
            value: 'https://legacy.example/1',
          ),
        );
    expect(await library.watchDanmakuEndpoints().first, [
      'https://legacy.example/1',
    ]);

    await library.addDanmakuEndpoint('https://second.example/2');
    expect(await library.watchDanmakuEndpoint().first, 'https://second.example/2');
    expect(await library.watchDanmakuEndpoints().first, [
      'https://second.example/2',
      'https://legacy.example/1',
    ]);

    await library.selectDanmakuEndpoint('https://legacy.example/1');
    expect(await library.watchDanmakuEndpoint().first, 'https://legacy.example/1');
    expect(await library.watchDanmakuEndpoints().first, [
      'https://legacy.example/1',
      'https://second.example/2',
    ]);

    await library.removeDanmakuEndpoint('https://legacy.example/1');
    expect(await library.watchDanmakuEndpoint().first, 'https://second.example/2');
    expect(await library.watchDanmakuEndpoints().first, [
      'https://second.example/2',
    ]);

    await library.removeDanmakuEndpoint('https://second.example/2');
    expect(await library.watchDanmakuEndpoint().first, isNull);
    expect(await library.watchDanmakuEndpoints().first, isEmpty);
  });
}
