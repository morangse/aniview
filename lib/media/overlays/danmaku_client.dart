import 'dart:convert';

import 'package:dio/dio.dart';

import '../media.dart';
import 'media_overlays.dart';
import '../sources/source_adapters.dart';

class DanmakuEpisodeMatch {
  const DanmakuEpisodeMatch({
    required this.episodeId,
    required this.animeTitle,
    required this.episodeTitle,
  });

  final int episodeId;
  final String animeTitle;
  final String episodeTitle;
}

class DanmakuClient {
  const DanmakuClient(this.http);

  final Dio http;

  static Uri normalizeEndpoint(String raw) => serverEndpoint(raw);

  static String suggestSearchKeyword(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return '';
    var clean = trimmed
        .replaceFirst(
          RegExp(r'\.(?:mp4|mkv|avi|ts|flv|webm)$', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^(?:[\[\(【（][^\]\)】）]+[\]\)】）]\s*)+'), '')
        .trim();
    final parts = clean
        .split(RegExp(r'\s*(?:/|／|\||｜)\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) clean = parts.first;
    if (RegExp(r'^[\u4e00-\u9fff\u3040-\u30ff]').hasMatch(clean)) {
      final shortened = clean
          .replaceFirst(
            RegExp(r"\s+[A-Za-z][A-Za-z0-9\s:!'.,&?\-]*$"),
            '',
          )
          .trim();
      if (shortened.isNotEmpty) clean = shortened;
    }
    return clean.isEmpty ? trimmed : clean;
  }

  static List<DanmakuEpisodeMatch> prioritizeMatches(
    List<DanmakuEpisodeMatch> matches, {
    String? episodeLabel,
  }) {
    final epText = episodeLabel?.trim() ?? '';
    final epNumMatch = RegExp(r'(\d+)').firstMatch(epText);
    if (epNumMatch == null || matches.length < 2) return matches;
    final target = int.tryParse(epNumMatch.group(1)!);
    if (target == null || target <= 0) return matches;
    final pattern = RegExp('(?<!\\d)0*$target(?!\\d)');
    final preferred = <DanmakuEpisodeMatch>[];
    final rest = <DanmakuEpisodeMatch>[];
    for (final m in matches) {
      if (pattern.hasMatch(m.episodeTitle)) {
        preferred.add(m);
      } else {
        rest.add(m);
      }
    }
    return preferred.isEmpty ? matches : [...preferred, ...rest];
  }

  static String describeError(Object error, {required String fallback}) {
    if (error is FormatException) return error.message;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '连接弹幕服务器超时，请检查网络或代理。';
        case DioExceptionType.connectionError:
          return '无法连接到弹幕服务器，请检查地址和网络。';
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          final headerMsg =
              error.response?.headers.value('x-error-message')?.trim();
          if (status == 401 || status == 403) {
            final detail = headerMsg != null && headerMsg.isNotEmpty
                ? '：$headerMsg'
                : '';
            return '服务器拒绝访问 (HTTP $status$detail)。若填写了官方 api.dandanplay.net，请改用免签兼容源地址。';
          }
          if (status == 404) {
            return '接口路径不存在 (HTTP 404)，请检查服务器根地址。';
          }
          if (status == 429) {
            return '请求过于频繁 (HTTP 429)，请稍后再试。';
          }
          if (status != null && status >= 500) {
            return '弹幕服务器异常 (HTTP $status)，请切换其他弹幕源或稍后再试。';
          }
          return status != null ? '$fallback (HTTP $status)' : fallback;
        case DioExceptionType.badCertificate:
          return '弹幕服务器 HTTPS 证书校验失败。';
        case DioExceptionType.cancel:
          return '请求已取消。';
        case DioExceptionType.unknown:
          return fallback;
      }
    }
    return fallback;
  }

  Future<List<DanmakuEpisodeMatch>> searchEpisodes(
    String baseEndpoint, {
    required String anime,
    String? episode,
  }) async {
    final trimmed = anime.trim();
    if (trimmed.isEmpty) return const [];
    final base = normalizeEndpoint(baseEndpoint);
    final uri = base.replace(
      path: '${base.path}/api/v2/search/episodes',
      queryParameters: {
        'anime': trimmed,
        if (episode != null && episode.trim().isNotEmpty)
          'episode': episode.trim(),
      },
    );
    final response = await http.getUri<dynamic>(
      uri,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map) {
      throw const FormatException('弹幕服务器返回了无法识别的搜索格式。');
    }
    final animes = data['animes'];
    if (animes is! List) return const [];
    final matches = <DanmakuEpisodeMatch>[];
    for (final entry in animes.whereType<Map>()) {
      final animeTitle = '${entry['animeTitle'] ?? ''}'.trim();
      final episodes = entry['episodes'];
      if (episodes is! List) continue;
      for (final ep in episodes.whereType<Map>()) {
        final rawId = ep['episodeId'];
        final episodeId = rawId is int ? rawId : int.tryParse('$rawId');
        final episodeTitle = '${ep['episodeTitle'] ?? ''}'.trim();
        if (episodeId != null && episodeId > 0) {
          matches.add(
            DanmakuEpisodeMatch(
              episodeId: episodeId,
              animeTitle: animeTitle,
              episodeTitle: episodeTitle.isEmpty
                  ? '第 $episodeId 话'
                  : episodeTitle,
            ),
          );
        }
      }
    }
    return matches;
  }

  Future<({String name, String payload, int count})> fetchComments(
    String baseEndpoint,
    int episodeId, {
    String? title,
  }) async {
    final base = normalizeEndpoint(baseEndpoint);
    final uri = base.replace(
      path: '${base.path}/api/v2/comment/$episodeId',
      queryParameters: const {'withRelated': 'true'},
    );
    final response = await http.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    final raw = response.data ?? '';
    final label = (title == null || title.trim().isEmpty)
        ? 'danmaku-$episodeId.json'
        : '${title.trim()}.json';
    final parsed = DanmakuTrack.parse(raw, label);
    return (name: label, payload: raw, count: parsed.items.length);
  }

  Future<({String name, String payload, int count})> fetchDirectUrl(
    String rawUrl,
  ) async {
    final uri = parsePlaybackUrl(rawUrl);
    if (!uri.isScheme('https')) {
      serverEndpoint(uri.origin);
    }
    final response = await http.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    final raw = response.data ?? '';
    final last = uri.pathSegments.lastOrNull?.toLowerCase() ?? '';
    final trimmed = raw.trimLeft();
    final filename = last.endsWith('.xml') || trimmed.startsWith('<')
        ? (last.endsWith('.xml') ? uri.pathSegments.last : 'online-danmaku.xml')
        : (last.endsWith('.json')
              ? uri.pathSegments.last
              : 'online-danmaku.json');
    final parsed = DanmakuTrack.parse(raw, filename);
    return (name: filename, payload: raw, count: parsed.items.length);
  }
}
