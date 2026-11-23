import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../features/anime/anime.dart';

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.title,
    required this.uri,
    this.subjectId,
    this.episodeId,
    this.seriesTitle,
    this.number,
    this.season,
    this.kind,
    this.width,
  });

  final String id;
  final String title;
  final Uri uri;
  final int? subjectId;
  final int? episodeId;
  final String? seriesTitle;
  final num? number;
  final int? season;
  final EpisodeKind? kind;
  final int? width;
}

const _rssNamespace = 'urn:aniview:catalog:v1';
const _maxEntries = 512;
final _catalogId = RegExp(r'^[A-Za-z0-9._-]{1,96}$');
final _badUrl = RegExp(r'[\s\x00-\x1f\x7f\\]|%(?![\da-fA-F]{2})');
final _rawUserInfo = RegExp(
  r'^[a-z][a-z0-9+.-]*://[^/?#]*@',
  caseSensitive: false,
);
const _mediaTypes = {
  'video/mp4',
  'application/vnd.apple.mpegurl',
  'application/x-mpegurl',
  'application/mpegurl',
  'audio/mpegurl',
  'audio/x-mpegurl',
  'video/mpegurl',
};

bool isCatalogId(String id) =>
    id != '.' && id != '..' && _catalogId.matchAsPrefix(id)?.end == id.length;

bool catalogHasUrlCredentials(String raw) => _rawUserInfo.hasMatch(raw);

Uri? catalogMediaUrl(Uri endpoint, String raw, {String? mime}) {
  if (!_isHttpOrigin(endpoint) ||
      raw.isEmpty ||
      raw.startsWith('//') ||
      _badUrl.hasMatch(raw) ||
      catalogHasUrlCredentials(raw)) {
    return null;
  }
  final reference = Uri.tryParse(raw);
  if (reference == null ||
      reference.hasFragment ||
      reference.authority.contains('@')) {
    return null;
  }
  final uri = endpoint.resolveUri(reference);
  if (!_isHttpOrigin(uri) || uri.origin != endpoint.origin) return null;

  final path = uri.path.toLowerCase();
  final mediaType = mime?.split(';').first.trim().toLowerCase();
  final knownExtension = path.endsWith('.mp4') || path.endsWith('.m3u8');
  final inferredType =
      mediaType == null ||
      mediaType.isEmpty ||
      mediaType == 'application/octet-stream';
  if (path.endsWith('.torrent') ||
      !(inferredType ? knownExtension : _mediaTypes.contains(mediaType))) {
    return null;
  }
  return uri;
}

bool _isHttpOrigin(Uri uri) =>
    (uri.isScheme('http') || uri.isScheme('https')) &&
    uri.hasAuthority &&
    uri.host.isNotEmpty &&
    !uri.authority.contains('@') &&
    uri.port >= 1 &&
    uri.port <= 65535;

List<CatalogEntry> parseJsonCatalog(String body, Uri endpoint) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic> ||
      decoded['schemaVersion'] != 1 ||
      decoded['resources'] is! List) {
    throw const FormatException('无效的 AniView JSON 目录。');
  }
  final resources = decoded['resources'] as List;
  if (resources.length > _maxEntries) {
    throw const FormatException('资源目录超过条目上限。');
  }
  return _uniqueEntries(resources.map((item) => _jsonEntry(item, endpoint)));
}

CatalogEntry? _jsonEntry(Object? item, Uri endpoint) {
  if (item is! Map<String, dynamic>) return null;
  final id = item['id'];
  final title = _catalogTitle(item['title']);
  final raw = item['url'];
  if (id is! String || !isCatalogId(id) || title == null || raw is! String) {
    return null;
  }
  final mime = item['mimeType'];
  if (mime != null && mime is! String) return null;
  final uri = catalogMediaUrl(endpoint, raw, mime: mime as String?);
  if (uri == null) return null;
  final subjectId = item['bangumiSubjectId'];
  final episodeId = item['bangumiEpisodeId'];
  final number = item['episodeNumber'];
  final season = item['season'];
  final rawKind = item['episodeKind'];
  final kind = EpisodeKind.values
      .where((kind) => kind.name == rawKind)
      .firstOrNull;
  final width = item['width'];
  if ((subjectId != null && (subjectId is! int || subjectId < 1)) ||
      (episodeId != null &&
          (episodeId is! int || episodeId < 1 || subjectId == null)) ||
      (number != null && (number is! num || !number.isFinite || number < 0)) ||
      (season != null && (season is! int || season < 0)) ||
      (rawKind != null && kind == null) ||
      (width != null && (width is! int || width < 1))) {
    return null;
  }
  return CatalogEntry(
    id: id,
    title: title,
    uri: uri,
    subjectId: subjectId as int?,
    episodeId: episodeId as int?,
    seriesTitle: _catalogTitle(item['seriesTitle']),
    number: number as num?,
    season: season as int?,
    kind: kind,
    width: width as int?,
  );
}

List<CatalogEntry> parseRssCatalog(
  String body,
  Uri endpoint, {
  bool acceptStandardGuids = false,
}) {
  if (body.contains('<!DOCTYPE')) {
    throw const FormatException('RSS 目录不能包含文档类型声明。');
  }
  final XmlDocument document;
  try {
    document = XmlDocument.parse(body);
  } on XmlException {
    throw const FormatException('无效的 RSS 目录。');
  }
  final rss = document.children.whereType<XmlElement>().singleOrNull;
  final channel = rss?.name.qualified == 'rss'
      ? rss!.findElements('channel').singleOrNull
      : null;
  if (channel == null) throw const FormatException('无效的 RSS 目录。');
  final items = channel.findElements('item').take(_maxEntries + 1).toList();
  if (items.length > _maxEntries) {
    throw const FormatException('资源目录超过条目上限。');
  }
  return _uniqueEntries(
    items.map((item) => _rssEntry(item, endpoint, acceptStandardGuids)),
  );
}

CatalogEntry? _rssEntry(
  XmlElement item,
  Uri endpoint,
  bool acceptStandardGuids,
) {
  final guid = item.getElement('guid')?.innerText.trim();
  final title = _catalogTitle(item.getElement('title')?.innerText);
  final enclosure = item.findElements('enclosure').singleOrNull;
  final raw = enclosure?.getAttribute('url');
  if (guid == null || guid.isEmpty || title == null || raw == null) {
    return null;
  }
  final id = acceptStandardGuids && guid.length <= 2048
      ? sha256.convert(utf8.encode(guid)).toString()
      : guid;
  if (!isCatalogId(id)) return null;
  final uri = catalogMediaUrl(
    endpoint,
    raw,
    mime: enclosure?.getAttribute('type'),
  );
  if (uri == null) return null;
  final subject = item.getElement('subjectId', namespaceUri: _rssNamespace);
  final episode = item.getElement('episodeId', namespaceUri: _rssNamespace);
  final subjectId = subject == null
      ? null
      : int.tryParse(subject.innerText.trim(), radix: 10);
  final episodeId = episode == null
      ? null
      : int.tryParse(episode.innerText.trim(), radix: 10);
  if ((subject != null && (subjectId == null || subjectId < 1)) ||
      (episode != null &&
          (episodeId == null || episodeId < 1 || subjectId == null))) {
    return null;
  }
  return CatalogEntry(
    id: id,
    title: title,
    uri: uri,
    subjectId: subjectId,
    episodeId: episodeId,
    seriesTitle: _catalogTitle(
      item.getElement('seriesTitle', namespaceUri: _rssNamespace)?.innerText,
    ),
  );
}

String? _catalogTitle(Object? value) {
  if (value is! String) return null;
  final title = value.trim();
  return title.isEmpty || title.length > 240 ? null : title;
}

List<CatalogEntry> _uniqueEntries(Iterable<CatalogEntry?> entries) {
  final seen = <String>{};
  final results = <CatalogEntry>[];
  for (final entry in entries.nonNulls) {
    if (!seen.add(entry.id)) {
      throw const FormatException('资源目录有重复的条目 ID。');
    }
    results.add(entry);
  }
  return List.unmodifiable(results);
}
