import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/catalog_entries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final endpoint = Uri.parse('https://media.example.test:8443/catalog/feed');

  test(
    'JSON entries keep the provider ID, episode metadata and signed URL',
    () {
      final entries = parseJsonCatalog('''
      {
        "schemaVersion": 1,
        "resources": [
          {
            "id": "clip_1-zh.mp4",
            "title": "章节 1",
            "url": "../stream/episode-1.mp4?signature=synthetic",
            "bangumiSubjectId": 400602,
            "bangumiEpisodeId": 90892,
            "seriesTitle": "示例条目",
            "episodeNumber": 1,
            "season": 2,
            "episodeKind": "regular",
            "width": 1920
          },
          {"id":"clip-2", "title":"Missing URL"},
          {"id":"clip-3", "title":"Other origin","url":"https://other.test/v.mp4"},
          {"id":"clip-4", "title":"Bad ID","url":"/v.mp4","bangumiEpisodeId":"123"}
        ]
      }
    ''', endpoint);
      final entry = entries.single;
      expect(entry.id, 'clip_1-zh.mp4');
      expect(entry.title, '章节 1');
      expect(
        entry.uri.toString(),
        'https://media.example.test:8443/stream/episode-1.mp4?signature=synthetic',
      );
      expect(entry.subjectId, 400602);
      expect(entry.episodeId, 90892);
      expect(entry.seriesTitle, '示例条目');
      expect(entry.number, 1);
      expect(entry.season, 2);
      expect(entry.kind, EpisodeKind.regular);
      expect(entry.width, 1920);
    },
  );

  test(
    'RSS keeps qualified IDs and ignores torrents and untrusted metadata',
    () {
      final items = parseRssCatalog('''
      <rss version="2.0" xmlns:view="urn:aniview:catalog:v1" xmlns:other="urn:other">
        <channel>
          <item>
            <guid isPermaLink="false">show-1</guid>
            <title>第一集 &amp; 正片</title>
            <enclosure url="/playlist?sig=fake&amp;clip=1" type="application/vnd.apple.mpegurl"/>
            <view:subjectId>17</view:subjectId>
            <view:episodeId>32</view:episodeId>
          </item>
          <item>
            <guid>show-2</guid><title>Second</title>
            <enclosure url="/episode2.mp4"/>
            <other:subjectId>100</other:subjectId>
            <episodeId>200</episodeId>
          </item>
          <item>
            <guid>torrent</guid><title>Torrent</title>
            <enclosure url="/sample.torrent" type="application/x-bittorrent"/>
          </item>
          <item>
            <guid>bad-identity</guid><title>Incorrect ID syntax</title>
            <enclosure url="/v.mp4"/>
            <view:episodeId>invalid</view:episodeId>
          </item>
        </channel>
      </rss>
    ''', endpoint);
      expect(items.map((entry) => entry.id), ['show-1', 'show-2']);
      expect(items.first.title, '第一集 & 正片');
      expect(items.first.subjectId, 17);
      expect(items.first.episodeId, 32);
      expect(items.first.uri.queryParameters, {'sig': 'fake', 'clip': '1'});
      expect(items.last.subjectId, isNull);
      expect(items.last.episodeId, isNull);
    },
  );

  test('rejects unsupported envelopes, DTDs and duplicate playable IDs', () {
    const duplicate = '''
      {"schemaVersion":1,"resources":[
        {"id":"clip","title":"A","url":"/a.mp4"},
        {"id":"clip","title":"B","url":"/b.mp4"}
      ]}
    ''';
    for (final body in [
      '[]',
      '{',
      '{"schemaVersion":2,"resources":[]}',
      duplicate,
    ]) {
      expect(() => parseJsonCatalog(body, endpoint), throwsFormatException);
    }
    for (final body in [
      '<rss><channel></rss>',
      '<rss/>',
      '<!DOCTYPE rss SYSTEM "https://example.test/feed.dtd"><rss><channel/></rss>',
      '<!-- no root -->',
    ]) {
      expect(() => parseRssCatalog(body, endpoint), throwsFormatException);
    }
    expect(
      parseJsonCatalog('{"schemaVersion":1,"resources":[]}', endpoint),
      isEmpty,
    );
    expect(parseRssCatalog('<rss><channel/></rss>', endpoint), isEmpty);
  });

  test('requires a safe same-origin direct media URL and stable IDs', () {
    for (final raw in [
      'magnet:?xt=urn:btih:123',
      'file:///sdcard/file.mp4',
      'javascript:test.mp4',
      'http://media.example.test:8443/clip.mp4',
      'https://media.example.test/clip.mp4',
      'https://user@media.example.test:8443/clip.mp4',
      'https://@media.example.test:8443/clip.mp4',
      '//media.example.test:8443/clip.mp4',
      '/clip.mp4#fragment',
      '/bad\\clip.mp4',
      '/bad clip.mp4',
      '/clip.mp4?malformed=%xx',
      '/clip.torrent',
      '/clip.webm',
    ]) {
      expect(catalogMediaUrl(endpoint, raw), isNull, reason: raw);
    }
    expect(
      catalogMediaUrl(endpoint, '/clip.torrent', mime: 'video/mp4'),
      isNull,
    );
    expect(
      catalogMediaUrl(endpoint, '/clip.mp4', mime: 'application/x-bittorrent'),
      isNull,
    );
    expect(catalogMediaUrl(endpoint, '/clip.MP4?sig=fake'), isNotNull);
    expect(catalogMediaUrl(endpoint, '/clip', mime: 'video/mp4'), isNotNull);
    expect(
      catalogMediaUrl(
        endpoint,
        '/clip.m3u8',
        mime: 'APPLICATION/X-MPEGURL; charset=utf-8',
      ),
      isNotNull,
    );
    for (final id in [
      '..',
      '.',
      '',
      'clip/1',
      'clip?yes',
      'clip\n',
      'x' * 97,
    ]) {
      expect(isCatalogId(id), false, reason: id);
    }
    expect(isCatalogId('clip.film-1_02'), true);
  });
}
