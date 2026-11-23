import 'dart:convert';

import '../media.dart';
import 'catalog_entries.dart';
import 'catalog_source.dart';

Map<String, dynamic> ruleObject(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('缺少$label。');
}

String ruleText(Object? value, String label, {int limit = 2048}) {
  if (value is String && value.trim().isNotEmpty && value.length <= limit) {
    return value.trim();
  }
  throw FormatException('$label格式无效。');
}

Uri animekoOrigin(String address) {
  if (address.contains('#') || catalogHasUrlCredentials(address)) {
    throw const FormatException('来源地址不接受片段或内嵌凭据。');
  }
  final uri = parsePlaybackUrl(address);
  parseCatalogEndpoint(uri.origin);
  return Uri.parse(uri.origin);
}

Uri? animekoPage(Uri origin, Uri base, String raw) {
  if (raw.isEmpty ||
      _invalidReference.hasMatch(raw) ||
      catalogHasUrlCredentials(raw) ||
      raw.startsWith('//')) {
    return null;
  }
  final ref = Uri.tryParse(raw);
  if (ref == null || ref.hasFragment) return null;
  final uri = base.resolveUri(ref);
  if ((!uri.isScheme('http') && !uri.isScheme('https')) ||
      !uri.hasAuthority ||
      uri.authority.contains('@') ||
      uri.origin != origin.origin) {
    return null;
  }
  return uri;
}

final _invalidReference = RegExp(r'[\s\x00-\x1f\x7f\\]|%(?![\da-fA-F]{2})');

Uri? animekoMedia(Uri origin, Uri base, String raw, {String? mime}) {
  final own = catalogMediaUrl(base, raw, mime: mime);
  if (own != null) return own;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.isScheme('https') ||
      !uri.hasAuthority ||
      uri.hasFragment ||
      uri.authority.contains('@') ||
      uri.origin == origin.origin ||
      _invalidReference.hasMatch(raw) ||
      catalogHasUrlCredentials(raw) ||
      !uri.host.contains('.') ||
      !RegExp(r'[a-z]').hasMatch(uri.host) ||
      uri.host.endsWith('.local')) {
    return null;
  }
  return catalogMediaUrl(uri, raw, mime: mime);
}

String animekoEncodeRecord(List<Object?> data) =>
    base64Url.encode(utf8.encode(jsonEncode(data)));

List<dynamic> animekoDecodeRecord(String data, int fields) {
  if (data.length <= 4096) {
    final result = jsonDecode(utf8.decode(base64Url.decode(data)));
    if (result is List && result.length == fields) return result;
  }
  throw const FormatException('播放记录格式无效。');
}

List<Object?> animekoJsonPath(Object? root, String path) {
  final tokens = _jsonSegments(path);
  var rows = <Object?>[root];
  for (final token in tokens) {
    final next = <Object?>[];
    for (final row in rows) {
      switch (token) {
        case '*':
          if (row is List) next.addAll(row.take(512 - next.length));
        case final int index:
          if (row is List && index < row.length) next.add(row[index]);
        case final String property:
          if (row is Map && row.containsKey(property)) next.add(row[property]);
      }
      if (next.length >= 512) break;
    }
    rows = next;
  }
  return rows;
}

String ruleJsonPath(Object? value, String name) {
  final path = ruleText(value, name, limit: 180);
  _jsonSegments(path);
  return path;
}

final _pathSegment = RegExp(
  r'''(?:\.([a-zA-Z_][a-zA-Z0-9_-]*)|\[(\*|[0-9]{1,4})\]|\[['"]([a-zA-Z_][a-zA-Z0-9_-]*)['"]\])''',
);

List<Object> _jsonSegments(String path) {
  if (!path.startsWith(r'$')) throw const FormatException('JSONPath 必须从根开始。');
  final parts = <Object>[];
  var position = 1;
  while (position < path.length) {
    final match = _pathSegment.matchAsPrefix(path, position);
    if (match == null || parts.length == 16) {
      throw const FormatException('JSONPath 超出当前支持的范围。');
    }
    final index = match.group(2);
    parts.add(
      index == null
          ? (match.group(1) ?? match.group(3)!)
          : index == '*'
          ? '*'
          : int.parse(index),
    );
    position = match.end;
  }
  return parts;
}

Object? animekoJsonField(Object? row, String? path) =>
    path == null ? null : animekoJsonPath(row, path).firstOrNull;

int? animekoId(Object? value) {
  final id = value is int ? value : int.tryParse(value?.toString() ?? '');
  return id != null && id > 0 ? id : null;
}
