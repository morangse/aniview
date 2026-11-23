import 'package:dio/dio.dart' show CancelToken;

import '../../features/anime/anime.dart';
import '../media.dart';

typedef AnimeSubject = Anime;

enum SourceKind {
  local,
  direct,
  jellyfin,
  emby,
  jsonFeed,
  rssFeed,
  webFeed,
  animekoRss,
  animekoWeb,
  animekoJson;

  bool get isCatalog => this == jsonFeed || this == rssFeed || this == webFeed;

  bool get isImportedRule =>
      this == animekoRss || this == animekoWeb || this == animekoJson;
}

enum SourceState {
  unchecked,
  checking,
  available,
  suspect,
  failed,
  login,
  forbidden,
}

extension SourceStateLabel on SourceState {
  String get label => switch (this) {
    SourceState.unchecked => '未检测',
    SourceState.checking => '检测中',
    SourceState.available => '可用',
    SourceState.suspect => '疑似不可用',
    SourceState.failed => '失败',
    SourceState.login => '需要登录',
    SourceState.forbidden => '权限不足',
  };
}

class SourceIssue implements Exception {
  const SourceIssue(this.state, this.label);
  final SourceState state;
  final String label;
  @override
  String toString() => label;
}

class MediaSearchRequest extends MediaRequest {
  const MediaSearchRequest({super.anime, super.episode});

  factory MediaSearchRequest.from(MediaRequest request) =>
      MediaSearchRequest(anime: request.anime, episode: request.episode);

  String get episodeKey => '${anime?.id ?? 0}/${episode?.id ?? 0}';
}

class SourceOffer {
  const SourceOffer({
    required this.sourceId,
    required this.resourceId,
    required this.label,
    this.saved,
    this.subjectId,
    this.episodeId,
    this.seriesTitle,
    this.season,
    this.number,
    this.kind,
    this.width,
    this.audioLanguages = const [],
    this.subtitleLanguages = const [],
    this.priority = 0,
    this.numberedWithinSubject = false,
    this.seriesOriginalTitle,
    this.seriesYear,
    this.seriesEpisodeCount,
  });

  final String sourceId;
  final String resourceId;
  final String label;
  final MediaCandidate? saved;
  final int? subjectId;
  final int? episodeId;
  final String? seriesTitle;
  final int? season;
  final num? number;
  final EpisodeKind? kind;
  final int? width;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final int priority;
  final bool numberedWithinSubject;
  final String? seriesOriginalTitle;
  final int? seriesYear;
  final int? seriesEpisodeCount;

  String get key => '$sourceId/$resourceId';
}

class MatchEvidence {
  const MatchEvidence(
    this.score,
    this.reason, {
    this.verified = false,
    this.rejected = false,
    this.tags = const [],
    this.reasons = const [],
    this.fansub,
    this.resolution,
    this.inferredWidth,
    this.isBatch = false,
    this.version,
  });
  final int score;
  final String reason;
  final bool verified;
  final bool rejected;
  final List<String> tags;
  final List<String> reasons;
  final String? fansub;
  final String? resolution;
  final int? inferredWidth;
  final bool isBatch;
  final int? version;
}

class RankedOffer {
  const RankedOffer(this.offer, this.match, this.health, this.rank);
  final SourceOffer offer;
  final MatchEvidence match;
  final SourceState health;
  final int rank;
}

class FetchResult {
  const FetchResult(this.offers, this.diagnostics);
  final List<RankedOffer> offers;
  final Map<String, SourceIssue> diagnostics;
}

class StreamAccess {
  const StreamAccess(
    this.uri, {
    this.headers = const {},
    this.restrictOrigin = false,
  });
  final Uri uri;
  final Map<String, String> headers;
  final bool restrictOrigin;
}

abstract interface class MediaSourceAdapter {
  String get id;
  String get name;
  int get priority;
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  });
  Future<StreamAccess> resolve(String resourceId);
  Future<void> testConnection();
}

/// Implemented only for services with a documented grant and approved API.
abstract interface class AuthorizedApiSource implements MediaSourceAdapter {}

String watchAssetKey(MediaCandidate media) => media.episodeId == null
    ? 'media/${media.id}'
    : 'episode/${media.subjectId}/${media.episodeId}';
