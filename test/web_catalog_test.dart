import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/web_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final endpoint = Uri.parse('https://media.example/library/index.html');

  test(
    'parses exact episode bindings and direct media relative to the page',
    () {
      final item = parseWebCatalog('''
      <!doctype html>
      <base href="https://external.example/">
      <video data-aniview-id="first-episode"
        data-bangumi-subject="400602" data-bangumi-episode="8766"
        data-title="第一集 &amp; 预告" data-series-title="自有番剧"
        data-season="1" data-number="1.5" data-kind="regular"
        data-width="1920" src=" ./first.m3u8 ">
        <source src="/ignored.mp4">
      </video>
    ''', endpoint).single;
      expect(item.id, 'first-episode');
      expect(item.title, '第一集 & 预告');
      expect(item.uri, Uri.parse('https://media.example/library/first.m3u8'));
      expect(item.subjectId, 400602);
      expect(item.episodeId, 8766);
      expect(item.seriesTitle, '自有番剧');
      expect(item.season, 1);
      expect(item.number, 1.5);
      expect(item.kind, EpisodeKind.regular);
      expect(item.width, 1920);
    },
  );

  test(
    'source variants inherit episode data and accept stable explicit IDs',
    () {
      final items = parseWebCatalog('''
      <video data-aniview-id="first" data-bangumi-subject="24"
        data-bangumi-episode="32" data-title="自制样片" data-width="720">
        <source src="/media/original.mp4" type="video/mp4"
          data-aniview-id="first-original" data-title="原片" data-width="1080">
        <source src="/media/preview.m3u8" type="application/vnd.apple.mpegurl">
      </video>
    ''', endpoint);
      expect(items.map((item) => item.id), ['first-original', 'first-2']);
      expect(items.map((item) => item.title), ['原片', '自制样片']);
      expect(items.map((item) => item.width), [1080, 720]);
      expect(items.map((item) => item.episodeId), [32, 32]);
    },
  );

  test('ignores scripts, unmarked content and cross-origin media', () {
    final items = parseWebCatalog('''
      <video src="/unmarked.mp4"></video>
      <script>
        const markup = '<video data-aniview-id="in-script" src="/fake.mp4">';
      </script>
      <iframe src="https://external.example/player">
        <video data-aniview-id="in-frame" src="/outside.mp4"></video>
      </iframe>
      <video data-aniview-id="external" src="//external.example/play.mp4"></video>
      <video data-aniview-id="scheme" src="http://media.example/play.mp4"></video>
      <video data-aniview-id="userinfo" src="https://secret@media.example/play.mp4"></video>
      <video data-aniview-id="script" src="javascript:video()"></video>
      <video data-aniview-id="local" src="/play.mp4"></video>
    ''', endpoint);
    expect(items.map((item) => item.id), ['local']);
  });

  test('rejects incomplete IDs, ambiguous IDs and overflow', () {
    expect(
      () => parseWebCatalog('''
        <video data-aniview-id="first" data-bangumi-episode="32"
          src="/play.mp4"></video>
      ''', endpoint),
      throwsFormatException,
    );
    expect(
      () => parseWebCatalog('''
        <video data-aniview-id="first" src="/play.mp4"></video>
        <video data-aniview-id="first" src="/again.mp4"></video>
      ''', endpoint),
      throwsFormatException,
    );
    final many = [
      for (var index = 0; index < 201; index++)
        '<video data-aniview-id="track-$index" src="/play.mp4"></video>',
    ];
    expect(() => parseWebCatalog(many.join(), endpoint), throwsFormatException);
  });
}
