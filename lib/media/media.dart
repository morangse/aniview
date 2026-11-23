import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../features/anime/anime.dart';

enum MediaKind { document, direct }

class MediaRequest {
  const MediaRequest({this.anime, this.episode});

  final Anime? anime;
  final Episode? episode;
}

class MediaCandidate {
  const MediaCandidate({
    required this.id,
    required this.uri,
    required this.kind,
    required this.title,
    required this.sourceName,
    this.subjectId,
    this.episodeId,
    this.episodeLabel,
    this.cover,
  });

  final String id;
  final Uri uri;
  final MediaKind kind;
  final String title;
  final String sourceName;
  final int? subjectId;
  final int? episodeId;
  final String? episodeLabel;
  final Uri? cover;

  MediaCandidate withUri(Uri uri) => MediaCandidate(
    id: id,
    uri: uri,
    kind: kind,
    title: title,
    sourceName: sourceName,
    subjectId: subjectId,
    episodeId: episodeId,
    episodeLabel: episodeLabel,
    cover: cover,
  );

  factory MediaCandidate.create({
    required Uri uri,
    required MediaKind kind,
    required String sourceName,
    required MediaRequest request,
  }) {
    final anime = request.anime;
    final episode = request.episode;
    final key = jsonEncode([anime?.id, episode?.id, uri.toString()]);
    return MediaCandidate(
      id: sha256.convert(utf8.encode(key)).toString(),
      uri: uri,
      kind: kind,
      title: anime?.title ?? sourceName,
      sourceName: sourceName,
      subjectId: anime?.id,
      episodeId: episode?.id,
      episodeLabel: episode?.label,
      cover: anime?.cover,
    );
  }
}

abstract interface class MediaSource {
  Future<List<MediaCandidate>> candidates(MediaRequest request);
}

class WatchProgress {
  const WatchProgress({
    required this.position,
    required this.duration,
    required this.completed,
    required this.updatedAt,
  });

  final Duration position;
  final Duration duration;
  final bool completed;
  final DateTime updatedAt;

  double get fraction => duration == Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  Duration get resumePosition => completed ? Duration.zero : position;
}

class WatchEntry {
  const WatchEntry(this.media, this.progress);

  final MediaCandidate media;
  final WatchProgress progress;
}

abstract interface class WatchProgressRepository {
  Future<WatchProgress?> load(String mediaId);
  Future<void> save(String mediaId, WatchProgress progress);
  Stream<List<WatchEntry>> watchHistory();
}

final _invalidUrl = RegExp(r'[\s\x00-\x1f\x7f\\]|%(?![\da-fA-F]{2})');

Uri parsePlaybackUrl(String input) {
  final value = input.trim();
  final uri = Uri.tryParse(value);
  if (_invalidUrl.hasMatch(value) ||
      uri == null ||
      !(uri.isScheme('https') || uri.isScheme('http')) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw const FormatException('请输入有效的 HTTP 或 HTTPS 视频地址。');
  }
  return uri.removeFragment();
}
