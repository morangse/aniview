import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/episode_matcher.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/release_title_parser.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses fansub, multi-language titles, season, episode, version, resolution and sub tags', () {
    final p1 = ReleaseTitleParser.parse(
      '[LoliHouse] 葬送的芙莉莲 / Sousou no Frieren - 01 [WebRip 1080p HEVC-10bit][简繁内封].mkv',
    );
    expect(p1.fansub, 'LoliHouse');
    expect(p1.titles, containsAll(['葬送的芙莉莲', 'Sousou no Frieren']));
    expect(p1.kind, EpisodeKind.regular);
    expect(p1.episode, 1);
    expect(p1.resolution, '1080p');
    expect(p1.inferredWidth, 1920);
    expect(p1.codec, 'HEVC');
    expect(p1.subtitleTags, containsAll(['简繁', '内封']));
    expect(p1.isBatch, false);

    final p2 = ReleaseTitleParser.parse(
      '【喵萌奶茶屋】【胆大党 / DAN DA DAN】第2季 [03v2][4K][AV1][简日内嵌]',
    );
    expect(p2.fansub, '喵萌奶茶屋');
    expect(p2.season, 2);
    expect(p2.episode, 3);
    expect(p2.version, 2);
    expect(p2.resolution, '2160p');
    expect(p2.inferredWidth, 3840);
    expect(p2.codec, 'AV1');
    expect(p2.subtitleTags, containsAll(['简日', '内嵌']));

    final batch = ReleaseTitleParser.parse(
      '[ANi] 葬送的芙莉莲 - 01-28 全28话 [1080p][简中]',
    );
    expect(batch.isBatch, true);
    expect(batch.episode, isNull);
    expect(batch.displayTags, contains('合集'));

    final ova = ReleaseTitleParser.parse('[Seed] 葬送的芙莉莲 OVA 2 [720p]');
    expect(ova.kind, EpisodeKind.special);
    expect(ova.episode, 2);
    expect(ova.resolution, '720p');
  });

  test('EpisodeMatcher 2.0 extracts evidence tags and ranks higher quality non-batch offers first', () {
    const anime = Anime(
      id: 400602,
      chineseName: '葬送的芙莉莲',
      originalName: '葬送のフリーレン',
      aliases: ['Sousou no Frieren'],
    );
    const ep1 = Episode(id: 1, number: 1, title: '冒险的终点');
    const request = MediaSearchRequest(anime: anime, episode: ep1);
    const matcher = EpisodeMatcher();

    const offer1080 = SourceOffer(
      sourceId: 'rss-1',
      resourceId: 'res-1',
      label: '[LoliHouse] 葬送的芙莉莲 / Sousou no Frieren - 01v2 [1080p HEVC][简繁内封].mp4',
    );
    const offer720 = SourceOffer(
      sourceId: 'rss-2',
      resourceId: 'res-2',
      label: '[Seed] 葬送的芙莉莲 - 01 [720p AVC][简中].mp4',
    );
    const offerBatch = SourceOffer(
      sourceId: 'rss-3',
      resourceId: 'res-3',
      label: '[ANi] 葬送的芙莉莲 - 01-28 [1080p][简繁]',
    );
    const offerEp2 = SourceOffer(
      sourceId: 'rss-4',
      resourceId: 'res-4',
      label: '[LoliHouse] 葬送的芙莉莲 - 02 [1080p HEVC][简繁内封].mp4',
    );

    final ev1080 = matcher.evaluate(request, offer1080);
    expect(ev1080.rejected, false);
    expect(ev1080.verified, false);
    expect(ev1080.score, 86);
    expect(ev1080.fansub, 'LoliHouse');
    expect(ev1080.resolution, '1080p');
    expect(ev1080.version, 2);
    expect(ev1080.tags, containsAll(['LoliHouse', '1080p', '简繁', 'HEVC']));
    expect(ev1080.reason, contains('第1话一致'));
    expect(ev1080.reason, contains('v2'));

    final evBatch = matcher.evaluate(request, offerBatch);
    expect(evBatch.isBatch, true);
    expect(evBatch.score, 42);
    expect(evBatch.reason, contains('合集'));

    expect(matcher.evaluate(request, offerEp2).rejected, true);

    const selector = MediaSelector();
    final ranked = selector.rank(
      [
        (offerBatch, evBatch),
        (offer720, matcher.evaluate(request, offer720)),
        (offer1080, ev1080),
      ],
      const {},
    );
    expect(ranked.map((r) => r.offer.sourceId).toList(), [
      'rss-1',
      'rss-2',
      'rss-3',
    ]);
  });
}
