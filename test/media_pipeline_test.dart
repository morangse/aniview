import 'dart:async';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/sources/episode_matcher.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

const anime = Anime(
  id: 41,
  originalName: 'City Lights Season 2',
  chineseName: '城市之光 第2季',
);
const eighth = Episode(id: 82, number: 8, title: 'S02 E08');
const request = MediaSearchRequest(anime: anime, episode: eighth);

SourceOffer candidate({
  String id = 'one',
  int? series = 41,
  int? episode = 82,
  int? season = 2,
  num? number = 8,
  EpisodeKind? kind = EpisodeKind.regular,
}) => SourceOffer(
  sourceId: id,
  resourceId: id,
  label: id,
  subjectId: series,
  episodeId: episode,
  season: season,
  number: number,
  kind: kind,
  seriesTitle: 'City Lights Season 2',
);

void main() {
  test('wrong season, wrong episode, missing number and specials are distinguished', () {
    const matcher = EpisodeMatcher();
    expect(matcher.evaluate(request, candidate()).verified, true);
    expect(matcher.evaluate(request, candidate(season: 1)).rejected, true);
    expect(matcher.evaluate(request, candidate(episode: 83)).rejected, true);
    expect(matcher.evaluate(request, candidate(number: 7)).rejected, true);
    expect(
      matcher.evaluate(request, candidate(kind: EpisodeKind.special)).rejected,
      true,
    );
    expect(matcher.evaluate(request, candidate(series: 42)).rejected, true);
    final needsApproval = matcher.evaluate(
      request,
      candidate(series: null, episode: null, number: null, kind: null),
    );
    expect(needsApproval.rejected, false);
    expect(needsApproval.verified, false);
  });

  test(
    'homonymous or substring-only candidates do not get automatic selection',
    () {
      const matcher = EpisodeMatcher();
      const homonym = SourceOffer(
        sourceId: 'one',
        resourceId: 'one',
        label: 'namesake',
        seriesTitle: 'City Lights Season 2',
        kind: EpisodeKind.regular,
        number: 8,
      );
      const partial = SourceOffer(
        sourceId: 'two',
        resourceId: 'two',
        label: 'different',
        seriesTitle: 'Remembering City Lights Season 2',
      );
      expect(matcher.evaluate(request, homonym).verified, false);
      expect(
        matcher.evaluate(request, homonym).score,
        greaterThan(matcher.evaluate(request, partial).score),
      );
    },
  );

  test('parallel source timeout is isolated and all-failure has labeled diagnostics', () async {
    final held = Completer<List<SourceOffer>>();
    final good = _Adapter('good', Future.value([candidate()]));
    final slow = _Adapter('slow', held.future);
    const fetcher = MediaFetcher(timeout: Duration(milliseconds: 12));
    final partial = await fetcher.query(request, [good, slow]);
    expect(partial.items, hasLength(1));
    expect(partial.issues['slow']?.state, SourceState.suspect);
    final denied = _Adapter(
      'denied',
      Future<List<SourceOffer>>.sync(
        () => throw const SourceIssue(SourceState.login, 'sign-in'),
      ),
    );
    final failed = await fetcher.query(request, [denied, slow]);
    expect(failed.items, isEmpty);
    expect(failed.issues.keys.toSet(), {'denied', 'slow'});
    held.complete([]);
  });

  test(
    'session preserves position and only visits each verified fallback once',
    () {
      final a = candidate(id: 'a');
      final b = candidate(id: 'b');
      final c = candidate(id: 'c', episode: null);
      const found = MatchEvidence(100, 'ID', verified: true);
      final entries = [
        RankedOffer(a, found, SourceState.available, 20),
        RankedOffer(b, found, SourceState.unchecked, 10),
        RankedOffer(
          c,
          const MatchEvidence(60, 'needs confirmation'),
          SourceState.available,
          5,
        ),
        RankedOffer(a, found, SourceState.unchecked, 3),
      ];
      final session = PlaybackSession(request, entries);
      expect(session.next(), a);
      session.resumeAt = const Duration(seconds: 95);
      expect(session.next(), b);
      expect(session.resumeAt!.inSeconds, 95);
      expect(session.next(), isNull);
      expect(PlaybackSession(request, entries, selected: c).next(), c);
    },
  );

  test(
    'manual correction survives rediscovery and secrets stay outside Drift',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final http = createMediaHttp();
      addTearDown(db.close);
      addTearDown(http.close);
      final store = SourceStore(db, TestVault());
      final library = LocalLibrary(db);
      final registry = MediaSourceRegistry(store, library, http);
      final resolver = MediaResolver(registry, store, library);
      const id = 'user-direct';
      await store.put(
        const ConfiguredSource(
          id: id,
          name: 'Ambiguous',
          kind: 'direct',
          endpoint: 'https://media.example',
          userId: '',
          enabled: true,
          priority: 0,
          offlineAllowed: false,
          subjectTitle: 'City Lights',
        ),
        secret: {
          'url': 'https://media.example/title.mp4?token=private',
          'headers': {'authorization': 'secret'},
        },
      );
      final unconfirmed = (await resolver.find(request)).offers.single;
      expect(unconfirmed.match.verified, false);
      await resolver.confirm(request, unconfirmed.offer);
      final confirmed = (await resolver.find(request)).offers.single;
      expect(confirmed.match.verified, true);
      final saved = await resolver.save(request, confirmed.offer);
      expect(saved.uri.scheme, 'aniview');
      expect(saved.uri.toString(), isNot(contains('private')));
      expect((await resolver.access(saved)).headers['authorization'], 'secret');
      final unrelated = await resolver.find(
        const MediaSearchRequest(
          anime: anime,
          episode: Episode(id: 84, number: 9, title: 'next'),
        ),
      );
      expect(unrelated.offers.single.match.verified, false);
    },
  );

  test('HTTP 200 containing HTML is unavailable and denied requests are categorized', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final http = createMediaHttp();
    addTearDown(db.close);
    addTearDown(http.close);
    var status = 200;
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (status == 200) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody.fromString('<html>sign in</html>', 200),
                headers: Headers.fromMap({
                  'content-type': ['text/html'],
                }),
              ),
            );
          } else {
            handler.reject(
              DioException.badResponse(
                statusCode: status,
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: status,
                ),
              ),
            );
          }
        },
      ),
    );
    final checker = SourceHealthChecker(http, SourceStore(db, TestVault()));
    final access = StreamAccess(Uri.parse('https://video.example/stream'));
    await expectLater(checker.checkMedia(access), throwsA(isA<SourceIssue>()));
    status = 403;
    await expectLater(
      checker.checkMedia(access),
      throwsA(
        isA<SourceIssue>().having(
          (failure) => failure.state,
          'state',
          SourceState.forbidden,
        ),
      ),
    );
  });
}

class _Adapter implements MediaSourceAdapter {
  const _Adapter(this.name, this.answer);
  @override
  final String name;
  final Future<List<SourceOffer>> answer;
  @override
  String get id => name;
  @override
  int get priority => 0;
  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) => answer;
  @override
  Future<StreamAccess> resolve(String resourceId) => throw UnimplementedError();
  @override
  Future<void> testConnection() async {}
}
