import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/database/app_database.dart';
import '../media.dart';
import 'catalog_entries.dart';
import 'catalog_source.dart';
import 'source_models.dart';

/// A declarative Animeko RSS search URL. The keyword is data in the query,
/// never part of the authority, path, request headers or method.
class AnimekoRssAddress {
  const AnimekoRssAddress._(this.template, this._uri);

  final String template;
  final Uri _uri;
  static const _placeholder = '{keyword}';
  static const _marker = 'ANIVIEW_RSS_QUERY_VALUE';

  Uri get origin => Uri.parse(_uri.origin);
  bool get searchesByTitle => template.contains(_placeholder);

  factory AnimekoRssAddress.parse(String input) {
    final template = input.trim();
    if (template.length > 2048 ||
        template.contains('#') ||
        template.contains(_marker) ||
        catalogHasUrlCredentials(template)) {
      throw const FormatException('RSS 搜索地址格式无效。');
    }
    final uri = parsePlaybackUrl(template.replaceAll(_placeholder, _marker));
    // Apply the normal endpoint transport policy to the feed's origin.
    parseCatalogEndpoint(uri.origin);
    if (uri.authority.toLowerCase().contains(_marker.toLowerCase()) ||
        uri.path.contains(_marker) ||
        uri.queryParametersAll.keys.any((key) => key.contains(_marker))) {
      throw const FormatException('RSS 搜索关键字必须出现在查询参数的值中。');
    }
    return AnimekoRssAddress._(template, uri);
  }

  Uri forTitle(String title) {
    if (!searchesByTitle) return _uri;
    return _uri.replace(
      queryParameters: {
        for (final entry in _uri.queryParametersAll.entries)
          entry.key: [
            for (final value in entry.value) _replaceTitle(value, title),
          ],
      },
    );
  }

  static String _replaceTitle(String value, String title) {
    if (!value.contains(_marker)) return value;
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        jsonDecode(value);
        final escaped = jsonEncode(title);
        return value.replaceAll(
          _marker,
          escaped.substring(1, escaped.length - 1),
        );
      } on FormatException {
        // An ordinary query value may begin with a brace.
      }
    }
    return value.replaceAll(_marker, title);
  }
}

class AnimekoRssSource implements MediaSourceAdapter {
  const AnimekoRssSource(this.config, this.http);

  final ConfiguredSource config;
  final Dio http;

  @override
  String get id => config.id;
  @override
  String get name => config.name;
  @override
  int get priority => config.priority;

  Future<List<CatalogEntry>> _read(
    String title, {
    CancelToken? cancelToken,
  }) async {
    try {
      final uri = AnimekoRssAddress.parse(config.endpoint).forTitle(title);
      final body = await readCatalogText(http, uri, cancelToken: cancelToken);
      return parseRssCatalog(body, uri, acceptStandardGuids: true);
    } on FormatException {
      throw const SourceIssue(SourceState.failed, 'RSS 地址或响应格式无效。');
    }
  }

  static String _prefix(CatalogEntry item) => sha256
      .convert(
        utf8.encode(jsonEncode([item.id, item.subjectId, item.episodeId])),
      )
      .toString();

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final title = request.anime?.title.trim() ?? '';
    if (title.length > 256 ||
        title.isEmpty &&
            AnimekoRssAddress.parse(config.endpoint).searchesByTitle) {
      return const [];
    }
    final encodedTitle = base64Url.encode(utf8.encode(title));
    final entries = await _read(title, cancelToken: cancelToken);
    return [
      for (final entry in entries)
        if ((request.anime == null ||
                entry.subjectId == null ||
                entry.subjectId == request.anime?.id) &&
            (request.episode == null ||
                entry.episodeId == null ||
                entry.episodeId == request.episode?.id))
          SourceOffer(
            sourceId: id,
            resourceId: '${_prefix(entry)}.$encodedTitle',
            label: entry.title,
            subjectId: entry.subjectId,
            episodeId: entry.episodeId,
            seriesTitle: entry.seriesTitle ?? entry.title,
            priority: priority,
          ),
    ];
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    if (resourceId.length <= 1440 && resourceId.indexOf('.') == 64) {
      final prefix = resourceId.substring(0, 64);
      final String title;
      try {
        title = utf8.decode(base64Url.decode(resourceId.substring(65)));
      } on FormatException {
        throw const SourceIssue(SourceState.failed, 'RSS 播放记录无效。');
      }
      if (title.length <= 256) {
        for (final item in await _read(title)) {
          if (_prefix(item) == prefix) {
            return StreamAccess(item.uri, restrictOrigin: true);
          }
        }
      }
    }
    throw const SourceIssue(SourceState.failed, 'RSS 中的媒体已移除。');
  }

  @override
  Future<void> testConnection() async {
    await _read('AniView');
  }
}
