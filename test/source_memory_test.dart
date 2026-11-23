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

const _anime = Anime(
  id: 400602,
  originalName: '葬送のフリーレン',
  chineseName: '葬送的芙莉莲',
  episodeCount: 28,
);
const _ep1 = Episode(id: 1001, number: 1, title: '冒险的终点');
const _ep2 = Episode(id: 1002, number: 2, title: '魔法使的旅途');
const _ep3 = Episode(id: 1003, number: 3, title: '杀人魔法');

class _RecordingSource implements AuthorizedApiSource {
  _RecordingSource({
    required this.id,
    required this.name,
    required this.onSearch,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  int get priority => 0;
  final Future<List<SourceOffer>> Function(MediaSearchRequest) onSearch;
  int searchCount = 0;

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    searchCount++;
    return onSearch(request);
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async =>
      StreamAccess(Uri.parse('https://video.example/$id/$resourceId.mp4'));

  @override
  Future<void> testConnection() async {}
}

void main() {
  test(
    'remembers working source & fansub per anime for fast-path auto-match and falls back on miss',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final http = createMediaHttp();
      addTearDown(db.close);
      addTearDown(http.close);

      final store = SourceStore(db, TestVault());
      final library = LocalLibrary(db);

      const primaryMissEp3 = true;
      final sourceA = _RecordingSource(
        id: 'rss-a',
        name: '线路 A',
        onSearch: (req) async {
          final ep = req.episode?.number ?? 0;
          if (ep == 3 && primaryMissEp3) {
            return const [];
          }
          if (ep == 2) {
            return const [
              SourceOffer(
                sourceId: 'rss-a',
                resourceId: 'a-2-sweet',
                label: '[SweetSub] 葬送的芙莉莲 - 02 [WebRip 1080p HEVC].mp4',
              ),
              SourceOffer(
                sourceId: 'rss-a',
                resourceId: 'a-2-loli',
                label: '[LoliHouse] 葬送的芙莉莲 - 02 [WebRip 1080p HEVC].mp4',
              ),
            ];
          }
          if (ep == 4) {
            return const [
              SourceOffer(
                sourceId: 'rss-a',
                resourceId: 'a-batch',
                label: '[LoliHouse] 葬送的芙莉莲 01-28 合集 [WebRip 1080p HEVC]',
              ),
            ];
          }
          return [
            SourceOffer(
              sourceId: 'rss-a',
              resourceId: 'a-$ep',
              label:
                  '[LoliHouse] 葬送的芙莉莲 - ${ep.toString().padLeft(2, '0')} [WebRip 1080p HEVC].mp4',
            ),
          ];
        },
      );

      final sourceB = _RecordingSource(
        id: 'rss-b',
        name: '线路 B',
        onSearch: (req) async {
          final ep = req.episode?.number ?? 0;
          return [
            SourceOffer(
              sourceId: 'rss-b',
              resourceId: 'b-$ep',
              label:
                  '[ANi] 葬送的芙莉莲 - ${ep.toString().padLeft(2, '0')} [1080P].mp4',
            ),
          ];
        },
      );

      final registry = MediaSourceRegistry(
        store,
        library,
        http,
        authorized: [sourceA, sourceB],
      );
      final resolver = MediaResolver(registry, store, library);

      const req1 = MediaSearchRequest(anime: _anime, episode: _ep1);
      final ep1First = await resolver.find(req1);
      expect(sourceA.searchCount, 1);
      expect(sourceB.searchCount, 1);
      final offerA1 = ep1First.offers.firstWhere(
        (e) => e.offer.sourceId == 'rss-a',
      );
      expect(offerA1.match.verified, false);

      await resolver.confirm(req1, offerA1.offer);
      expect(await resolver.verifiedSource(_anime.id), 'rss-a');
      expect(await resolver.preferredFansub(_anime.id), 'LoliHouse');

      sourceA.searchCount = 0;
      sourceB.searchCount = 0;

      const req2 = MediaSearchRequest(anime: _anime, episode: _ep2);
      final ep2Fast = await resolver.find(req2);
      expect(sourceA.searchCount, 1);
      expect(sourceB.searchCount, 0);
      expect(ep2Fast.offers, hasLength(2));
      expect(ep2Fast.offers.first.offer.resourceId, 'a-2-loli');
      expect(PlaybackSession.canSelectAutomatically(ep2Fast.offers.first), true);

      sourceA.searchCount = 0;
      sourceB.searchCount = 0;
      final ep2All = await resolver.findAll(req2);
      expect(sourceA.searchCount, 1);
      expect(sourceB.searchCount, 1);
      expect(ep2All.offers.length, 3);

      sourceA.searchCount = 0;
      sourceB.searchCount = 0;
      const req3 = MediaSearchRequest(anime: _anime, episode: _ep3);
      final ep3Fallback = await resolver.find(req3);
      expect(sourceA.searchCount, 1);
      expect(sourceB.searchCount, 1);
      expect(ep3Fallback.offers.single.offer.sourceId, 'rss-b');
      expect(ep3Fallback.offers.single.match.verified, false);

      const ep4 = Episode(id: 1004, number: 4, title: '魂之眠地');
      final ep4Batch = await resolver.find(
        const MediaSearchRequest(anime: _anime, episode: ep4),
      );
      expect(ep4Batch.offers.first.match.verified, false);
    },
  );

  test('ignores local and direct single-URL sources for anime memory', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final http = createMediaHttp();
    addTearDown(db.close);
    addTearDown(http.close);

    final store = SourceStore(db, TestVault());
    final library = LocalLibrary(db);
    await store.put(
      const ConfiguredSource(
        id: 'direct-ep1',
        name: 'direct-ep1',
        kind: 'direct',
        endpoint: 'https://video.example',
        userId: '',
        enabled: true,
        priority: 0,
        offlineAllowed: false,
        subjectTitle: '葬送的芙莉莲',
      ),
      secret: {'url': 'https://video.example/01.mp4', 'headers': {}},
    );

    final resolver = MediaResolver(
      MediaSourceRegistry(store, library, http),
      store,
      library,
    );

    await resolver.rememberWorkingSource(400602, 'local', label: '01.mp4');
    await resolver.rememberWorkingSource(
      400602,
      'direct-ep1',
      label: '[LoliHouse] 葬送的芙莉莲 - 01.mp4',
    );
    expect(await resolver.verifiedSource(400602), isNull);
  });
}
