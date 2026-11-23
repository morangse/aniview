import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/database/app_database.dart';
import '../media.dart';
import 'catalog_entries.dart';
import 'episode_matcher.dart';
import 'source_adapters.dart';
import 'source_models.dart';
import 'source_store.dart';
import 'web_catalog.dart';

Uri parseCatalogEndpoint(String input) {
  if (catalogHasUrlCredentials(input.trim())) {
    throw const FormatException('目录地址不接受内嵌凭据。');
  }
  serverEndpoint(input);
  final uri = parsePlaybackUrl(input);
  return uri.path.isEmpty ? uri.replace(path: '/') : uri;
}

Future<String> readCatalogText(
  Dio http,
  Uri uri, {
  CancelToken? cancelToken,
  Map<String, String> headers = const {},
  String method = 'GET',
  Object? data,
}) {
  final cancellation = cancelToken ?? CancelToken();
  return _readCatalog(http, uri, cancellation, headers, method, data).timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      cancellation.cancel();
      throw const SourceIssue(SourceState.suspect, '读取目录超时。');
    },
  );
}

Future<String> _readCatalog(
  Dio http,
  Uri uri,
  CancelToken cancellation,
  Map<String, String> headers,
  String method,
  Object? data,
) async {
  try {
    final response = await http.requestUri<ResponseBody>(
      uri,
      data: data,
      cancelToken: cancellation,
      options: Options(
        method: method,
        headers: headers,
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status == 200,
      ),
    );
    final body = response.data;
    if (body == null) throw const FormatException('片源目录没有内容。');
    final bytes = <int>[];
    await for (final part in body.stream) {
      if (bytes.length + part.length > 512 * 1024) {
        cancellation.cancel();
        throw const FormatException('片源目录超过 512 KiB。');
      }
      bytes.addAll(part);
    }
    return utf8.decode(bytes);
  } on DioException catch (error) {
    throw sourceHttpFailure(error);
  }
}

class CatalogSource implements AuthorizedApiSource {
  const CatalogSource(this.config, this.store, this.http);

  final ConfiguredSource config;
  final SourceStore store;
  final Dio http;

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  int get priority => config.priority;

  Future<({List<CatalogEntry> items, Map<String, String> headers})> _entries([
    CancelToken? cancellation,
  ]) async {
    try {
      final endpoint = parseCatalogEndpoint(config.endpoint);
      final secret = await store.credentials(id);
      final headers = Map<String, String>.from(
        secret?['headers'] as Map? ?? const {},
      );
      final body = await readCatalogText(
        http,
        endpoint,
        cancelToken: cancellation,
        headers: headers,
      );
      final items = switch (SourceKind.values.byName(config.kind)) {
        SourceKind.jsonFeed => parseJsonCatalog(body, endpoint),
        SourceKind.rssFeed => parseRssCatalog(body, endpoint),
        SourceKind.webFeed => parseWebCatalog(body, endpoint),
        _ => throw const FormatException('不支持的目录类型。'),
      };
      return (items: items, headers: headers);
    } on FormatException {
      throw const SourceIssue(SourceState.failed, '目录格式无效或超出限制。');
    }
  }

  String _resourceId(CatalogEntry entry) {
    final identity = jsonEncode([
      config.endpoint,
      entry.id,
      entry.subjectId,
      entry.episodeId,
      entry.season,
      entry.number,
      entry.kind?.name,
      if (entry.subjectId == null) entry.seriesTitle ?? entry.title,
    ]);
    return sha256.convert(utf8.encode(identity)).toString();
  }

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final data = await _entries(cancelToken);
    final anime = request.anime;
    final titles = anime == null
        ? const <String>{}
        : {anime.originalName, anime.chineseName, ...anime.aliases}
              .map(EpisodeMatcher.normalizeTitle)
              .where((title) => title.isNotEmpty)
              .toSet();
    return [
      for (final entry in data.items)
        if ((anime == null ||
                (entry.subjectId != null
                    ? entry.subjectId == anime.id
                    : titles.contains(
                        EpisodeMatcher.normalizeTitle(
                          entry.seriesTitle ?? entry.title,
                        ),
                      ))) &&
            (request.episode == null ||
                entry.episodeId == null ||
                entry.episodeId == request.episode!.id))
          SourceOffer(
            sourceId: id,
            resourceId: _resourceId(entry),
            label: entry.title,
            subjectId: entry.subjectId,
            episodeId: entry.episodeId,
            seriesTitle: entry.seriesTitle ?? entry.title,
            season: entry.season,
            number: entry.number,
            kind: entry.kind,
            width: entry.width,
            priority: priority,
          ),
    ];
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    final data = await _entries();
    for (final entry in data.items) {
      if (_resourceId(entry) == resourceId) {
        return StreamAccess(
          entry.uri,
          headers: data.headers,
          restrictOrigin: true,
        );
      }
    }
    throw const SourceIssue(SourceState.failed, '目录中的资源已移除或剧集发生变化。');
  }

  @override
  Future<void> testConnection() async {
    final data = await _entries();
    if (data.items.isEmpty) {
      throw const SourceIssue(SourceState.suspect, '目录可访问，但没有支持的 MP4 或 HLS。');
    }
  }
}
