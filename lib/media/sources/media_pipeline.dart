import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/database/app_database.dart';
import '../../core/database/local_library.dart';
import '../media.dart';
import 'animeko_json_source.dart';
import 'animeko_rss_source.dart';
import 'animeko_web_source.dart';
import 'catalog_source.dart';
import 'episode_matcher.dart';
import 'source_adapters.dart';
import 'source_models.dart';
import 'source_store.dart';

class MediaSourceRegistry {
  const MediaSourceRegistry(
    this.store,
    this.library,
    this.http, {
    this.authorized = const [],
  });
  final SourceStore store;
  final LocalLibrary library;
  final Dio http;
  final List<AuthorizedApiSource> authorized;

  MediaSourceAdapter adapter(ConfiguredSource config) =>
      switch (SourceKind.values.byName(config.kind)) {
        SourceKind.local => LocalSource(config, library),
        SourceKind.direct => DirectUrlSource(config, store, library),
        SourceKind.jellyfin => JellyfinSource(config, store, http),
        SourceKind.emby => EmbySource(config, store, http),
        SourceKind.animekoRss => AnimekoRssSource(config, http),
        SourceKind.animekoWeb => AnimekoWebSource(config, http),
        SourceKind.animekoJson => AnimekoJsonSource(config, http),
        SourceKind.jsonFeed ||
        SourceKind.rssFeed ||
        SourceKind.webFeed => CatalogSource(config, store, http),
      };

  Future<List<MediaSourceAdapter>> enabledSources() async => [
    for (final item in await store.sources())
      if (item.enabled) adapter(item),
    ...authorized,
  ];

  Future<MediaSourceAdapter> enabledAdapter(String id) async {
    final registered = authorized
        .where((source) => source.id == id)
        .firstOrNull;
    if (registered != null) return registered;
    final config = await store.byId(id);
    if (config == null || !config.enabled) {
      throw const SourceIssue(SourceState.failed, '该片源已禁用或删除。');
    }
    return adapter(config);
  }
}

class MediaFetcher {
  const MediaFetcher({
    this.parallelism = 3,
    this.timeout = const Duration(seconds: 9),
  }) : assert(parallelism > 0);
  final int parallelism;
  final Duration timeout;

  Stream<({List<SourceOffer> items, Map<String, SourceIssue> issues})>
  queryStream(MediaSearchRequest request, List<MediaSourceAdapter> sources) {
    final items = <SourceOffer>[];
    final issues = <String, SourceIssue>{};
    final queue = sources.toList();
    final cancelTokens = <CancelToken>[];
    var activeCount = 0;
    var emitted = false;
    var canceled = false;

    late final StreamController<
      ({List<SourceOffer> items, Map<String, SourceIssue> issues})
    >
    controller;

    void finishIfDone() {
      if (canceled || controller.isClosed) return;
      if (queue.isEmpty && activeCount == 0) {
        if (!emitted) {
          emitted = true;
          controller.add((items: const [], issues: const {}));
        }
        unawaited(controller.close());
      }
    }

    void pump() {
      while (!canceled && activeCount < parallelism && queue.isNotEmpty) {
        final source = queue.removeAt(0);
        final cancel = CancelToken();
        cancelTokens.add(cancel);
        activeCount++;

        Future<List<SourceOffer>> searchFuture;
        try {
          searchFuture = source
              .search(request, cancelToken: cancel)
              .timeout(
                timeout,
                onTimeout: () {
                  cancel.cancel();
                  throw TimeoutException('Source query timed out', timeout);
                },
              );
        } on Object catch (error, stackTrace) {
          searchFuture = Future.error(error, stackTrace);
        }

        unawaited(
          searchFuture.then<void>(
            (result) {
              activeCount--;
              if (canceled || controller.isClosed) return;
              items.addAll(result);
              emitted = true;
              controller.add((items: items.toList(), issues: Map.of(issues)));
              pump();
              finishIfDone();
            },
            onError: (Object error, StackTrace _) {
              activeCount--;
              if (canceled || controller.isClosed) return;
              if (error is SourceIssue) {
                issues[source.name] = error;
              } else if (error is TimeoutException) {
                issues[source.name] = const SourceIssue(
                  SourceState.suspect,
                  '查询超时',
                );
              } else if (!cancel.isCancelled) {
                issues[source.name] = const SourceIssue(
                  SourceState.failed,
                  '无法读取该片源',
                );
              }
              emitted = true;
              controller.add((items: items.toList(), issues: Map.of(issues)));
              pump();
              finishIfDone();
            },
          ),
        );
      }
      finishIfDone();
    }

    controller = StreamController(
      onListen: pump,
      onCancel: () {
        canceled = true;
        for (final cancel in cancelTokens) {
          if (!cancel.isCancelled) cancel.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<({List<SourceOffer> items, Map<String, SourceIssue> issues})> query(
    MediaSearchRequest request,
    List<MediaSourceAdapter> sources,
  ) async {
    return await queryStream(request, sources).last;
  }
}

class SourceHealthChecker {
  const SourceHealthChecker(this.http, this.store);
  final Dio http;
  final SourceStore store;

  Future<SourceState> test(
    ConfiguredSource config,
    MediaSourceAdapter adapter,
  ) async {
    await store.recordHealth(config.id, SourceState.checking);
    try {
      if (config.kind == SourceKind.direct.name &&
          config.id != 'legacy-direct') {
        await checkMedia(await adapter.resolve(config.id));
      } else {
        await adapter.testConnection().timeout(const Duration(seconds: 8));
      }
      await store.recordHealth(config.id, SourceState.available);
      return SourceState.available;
    } on SourceIssue catch (issue) {
      await store.recordHealth(config.id, issue.state);
      rethrow;
    } on Exception {
      await store.recordHealth(config.id, SourceState.suspect);
      throw const SourceIssue(SourceState.suspect, '检测超时或网络不可用。');
    }
  }

  Future<void> checkMedia(StreamAccess access) async {
    if (!access.uri.isScheme('http') && !access.uri.isScheme('https')) return;
    try {
      final response = await http.getUri<ResponseBody>(
        access.uri,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            ...access.headers,
            'Range': 'bytes=0-1023',
            'Accept-Encoding': 'identity',
          },
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const SourceIssue(SourceState.failed, '地址没有媒体内容。');
      }
      final prefix = <int>[];
      await for (final chunk in body.stream) {
        prefix.addAll(chunk.take(32 - prefix.length));
        if (prefix.length >= 32) break;
      }
      final mime = response.headers.value('content-type')?.toLowerCase() ?? '';
      final header = String.fromCharCodes(prefix).trimLeft();
      final signature =
          header.startsWith('#EXTM3U') ||
          header.startsWith('\ufeff#EXTM3U') ||
          (prefix.length >= 8 &&
              String.fromCharCodes(prefix.sublist(4, 8)) == 'ftyp') ||
          (prefix.length >= 4 &&
              prefix[0] == 0x1a &&
              prefix[1] == 0x45 &&
              prefix[2] == 0xdf &&
              prefix[3] == 0xa3);
      if (prefix.isEmpty ||
          mime.contains('text/html') ||
          mime.contains('application/json') ||
          (!signature && !mime.startsWith('video/'))) {
        throw const SourceIssue(SourceState.failed, '地址有响应，但没有识别到视频或 HLS 清单。');
      }
    } on DioException catch (error) {
      throw sourceHttpFailure(error);
    }
  }
}

class MediaSelector {
  const MediaSelector();

  List<RankedOffer> rank(
    Iterable<(SourceOffer, MatchEvidence)> candidates,
    Map<String, SourceHealthRow> health, {
    String? preferred,
    String? preferredAudio,
    String? preferredSubtitle,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final results = candidates.map((item) {
      final (offer, evidence) = item;
      final record = health[offer.key] ?? health[offer.sourceId];
      final fresh =
          record != null &&
          now - record.updatedAt < const Duration(hours: 6).inMilliseconds;
      final state = fresh
          ? SourceState.values.byName(record.state)
          : SourceState.unchecked;
      final reliability = record == null
          ? 0
          : ((record.successes + 1) /
                    (record.successes + record.failures + 2) *
                    20)
                .round();
      final latency = record?.startupMs ?? 0;
      final effectiveWidth = offer.width ?? evidence.inferredWidth ?? 0;
      final score =
          (evidence.verified ? 1500 : 0) +
          evidence.score * 2 +
          (preferred == offer.sourceId ? 90 : 0) +
          offer.priority * 5 +
          (state == SourceState.available
              ? 25
              : _blocked(state)
              ? -600
              : 0) +
          reliability -
          (latency ~/ 300).clamp(0, 22) -
          (record?.buffers ?? 0).clamp(0, 20) +
          (effectiveWidth ~/ 192).clamp(0, 20) +
          (evidence.isBatch ? -120 : 0) +
          ((evidence.version ?? 0) >= 2 ? 6 : 0) +
          (evidence.tags.any((t) => t.contains('简')) ? 6 : 0) +
          (offer.audioLanguages.contains(preferredAudio) ? 8 : 0) +
          (offer.subtitleLanguages.contains(preferredSubtitle) ? 8 : 0);
      return RankedOffer(offer, evidence, state, score);
    }).toList();
    results.sort((a, b) {
      final byRank = b.rank.compareTo(a.rank);
      return byRank == 0 ? a.offer.key.compareTo(b.offer.key) : byRank;
    });
    return results;
  }

  static bool _blocked(SourceState state) => const {
    SourceState.failed,
    SourceState.login,
    SourceState.forbidden,
  }.contains(state);
}

class MediaResolver {
  const MediaResolver(
    this.registry,
    this.store,
    this.library, {
    this.fetcher = const MediaFetcher(),
    this.matcher = const EpisodeMatcher(),
    this.selector = const MediaSelector(),
  });
  final MediaSourceRegistry registry;
  final SourceStore store;
  final LocalLibrary library;
  final MediaFetcher fetcher;
  final EpisodeMatcher matcher;
  final MediaSelector selector;

  Future<String?> preferredSource(int? subjectId) =>
      store.preference('preferred-source.${subjectId ?? 0}');

  Stream<FetchResult> watch(MediaSearchRequest request) async* {
    final sources = await registry.enabledSources();
    final preferred = await store.preference(
      'preferred-source.${request.anime?.id ?? 0}',
    );
    final preferredAudio = await store.preference('media.audio-language');
    final preferredSubtitle = await store.preference('media.subtitle-language');
    final health = await store.health();
    final recorded = await store.matches(request.episodeKey);
    final recordedThisSession = <String>{};

    await for (final result in fetcher.queryStream(request, sources)) {
      final matches = <(SourceOffer, MatchEvidence)>[];
      for (final offer in result.items) {
        final automatic = matcher.evaluate(request, offer);
        final evidence =
            !automatic.rejected && recorded[offer.key]?.confirmed == true
            ? const MatchEvidence(100, '已记住手动确认的匹配', verified: true)
            : automatic;
        if (request.anime != null && recordedThisSession.add(offer.key)) {
          unawaited(store.recordMatch(request.episodeKey, offer.key, evidence));
        }
        if (!evidence.rejected) matches.add((offer, evidence));
      }
      final items = selector.rank(
        matches,
        health,
        preferred: preferred,
        preferredAudio: preferredAudio,
        preferredSubtitle: preferredSubtitle,
      );
      yield FetchResult(items, result.issues);
    }
  }

  Future<FetchResult> find(MediaSearchRequest request) async {
    final result = await fetcher.query(
      request,
      await registry.enabledSources(),
    );
    final recorded = await store.matches(request.episodeKey);
    final matches = <(SourceOffer, MatchEvidence)>[];
    for (final offer in result.items) {
      final automatic = matcher.evaluate(request, offer);
      final evidence =
          !automatic.rejected && recorded[offer.key]?.confirmed == true
          ? const MatchEvidence(100, '已记住手动确认的匹配', verified: true)
          : automatic;
      if (request.anime != null) {
        await store.recordMatch(request.episodeKey, offer.key, evidence);
      }
      if (!evidence.rejected) matches.add((offer, evidence));
    }
    final items = selector.rank(
      matches,
      await store.health(),
      preferred: await store.preference(
        'preferred-source.${request.anime?.id ?? 0}',
      ),
      preferredAudio: await store.preference('media.audio-language'),
      preferredSubtitle: await store.preference('media.subtitle-language'),
    );
    return FetchResult(items, result.issues);
  }

  Future<void> confirm(MediaSearchRequest request, SourceOffer offer) =>
      store.recordMatch(
        request.episodeKey,
        offer.key,
        const MatchEvidence(100, '手动确认', verified: true),
        confirmed: true,
      );

  Future<MediaCandidate> save(
    MediaSearchRequest request,
    SourceOffer offer,
  ) async {
    if (offer.saved case final saved?) return saved;
    final result = MediaCandidate.create(
      uri: Uri(
        scheme: 'aniview',
        host: 'media',
        pathSegments: [offer.sourceId, offer.resourceId],
      ),
      kind: MediaKind.direct,
      sourceName: offer.label,
      request: request,
    );
    await store.db.transaction(() async {
      await library.addMedia(result);
      await store.link(
        MediaLink(
          mediaId: result.id,
          sourceId: offer.sourceId,
          resourceKey: offer.key,
          resourceId: offer.resourceId,
        ),
      );
    });
    return result;
  }

  Future<StreamAccess> access(MediaCandidate candidate) async {
    final link = await store.linked(candidate.id);
    if (link != null) {
      final adapter = await registry.enabledAdapter(link.sourceId);
      return adapter.resolve(link.resourceId);
    }
    await registry.enabledAdapter(
      candidate.kind == MediaKind.document ? 'local' : 'legacy-direct',
    );
    return StreamAccess(candidate.uri);
  }
}

class PlaybackSession {
  PlaybackSession(
    this.request,
    List<RankedOffer> ranked, {
    SourceOffer? selected,
    this._limit = 4,
  }) : _queue = [
         ?selected,
         for (final entry in ranked)
           if (canSelectAutomatically(entry) &&
               entry.offer.key != selected?.key)
             entry.offer,
       ];
  final MediaSearchRequest request;
  final List<SourceOffer> _queue;
  final int _limit;
  final Set<String> _tried = {};
  Duration? resumeAt;
  Duration? previousDuration;
  final List<String> failedLabels = [];
  SourceOffer? current;

  static bool canSelectAutomatically(RankedOffer entry) =>
      entry.match.verified && !MediaSelector._blocked(entry.health);

  SourceOffer? next() {
    if (_tried.length >= _limit) return null;
    for (final candidate in _queue) {
      if (_tried.add(candidate.key)) return current = candidate;
    }
    return null;
  }
}
