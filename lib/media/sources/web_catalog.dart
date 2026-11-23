import 'package:html/parser.dart' as html;

import '../../features/anime/anime.dart';
import 'catalog_entries.dart';

const _maxElements = 512;
const _maxEntries = 200;

/// Reads the explicitly marked HTML videos in an authorized catalog.
List<CatalogEntry> parseWebCatalog(String body, Uri endpoint) {
  if (body.length > 512 * 1024) {
    throw const FormatException('网页目录超出大小限制。');
  }
  final entries = <CatalogEntry>[];
  final seen = <String>{};
  final document = html.parse(body);
  final videos = document.querySelectorAll('video[data-aniview-id]');
  var elements = videos.length;
  if (elements > _maxElements) {
    throw const FormatException('网页目录的视频元素超出限制。');
  }
  for (final video in videos) {
    final attributes = video.attributes;
    final videoId = attributes['data-aniview-id']!.trim();
    if (!isCatalogId(videoId)) {
      throw const FormatException('网页目录的视频 ID 无效。');
    }
    final subjectId = _positiveInt(attributes['data-bangumi-subject']);
    final episodeId = _positiveInt(attributes['data-bangumi-episode']);
    if (episodeId != null && subjectId == null) {
      throw const FormatException('网页目录的单集缺少 Bangumi 条目 ID。');
    }
    final title = _label(attributes['data-title']) ?? videoId;
    final seriesTitle = _label(attributes['data-series-title']);
    final season = _positiveInt(attributes['data-season']);
    final number = _episodeNumber(attributes['data-number']);
    final kind = switch (attributes['data-kind']) {
      null => null,
      'regular' => EpisodeKind.regular,
      'special' => EpisodeKind.special,
      'extra' => EpisodeKind.extra,
      _ => throw const FormatException('网页目录的剧集类型无效。'),
    };
    final width = _positiveInt(attributes['data-width']);

    void add(
      String id,
      String raw, {
      String? mime,
      String? variantTitle,
      int? variantWidth,
    }) {
      final uri = catalogMediaUrl(endpoint, raw.trim(), mime: mime);
      if (uri == null) return;
      if (!isCatalogId(id) || !seen.add(id)) {
        throw const FormatException('网页目录的资源 ID 无效或重复。');
      }
      if (entries.length >= _maxEntries) {
        throw const FormatException('网页目录的资源数量超出限制。');
      }
      entries.add(
        CatalogEntry(
          id: id,
          title: variantTitle ?? title,
          uri: uri,
          subjectId: subjectId,
          episodeId: episodeId,
          seriesTitle: seriesTitle,
          number: number,
          season: season,
          kind: kind,
          width: variantWidth ?? width,
        ),
      );
    }

    final src = attributes['src'];
    if (src != null && src.trim().isNotEmpty) {
      add(videoId, src);
      continue;
    }
    var index = 0;
    for (final source in video.children.where(
      (child) => child.localName == 'source',
    )) {
      if (++elements > _maxElements) {
        throw const FormatException('网页目录的来源元素超出限制。');
      }
      index++;
      if (source.attributes['src'] case final src?) {
        add(
          source.attributes['data-aniview-id']?.trim() ?? '$videoId-$index',
          src,
          mime: source.attributes['type'],
          variantTitle: _label(source.attributes['data-title']),
          variantWidth: _positiveInt(source.attributes['data-width']),
        );
      }
    }
  }
  return List.unmodifiable(entries);
}

int? _positiveInt(String? raw) {
  if (raw == null) return null;
  final value = int.tryParse(raw, radix: 10);
  if (value == null || value <= 0) {
    throw const FormatException('网页目录的数字属性无效。');
  }
  return value;
}

num? _episodeNumber(String? raw) {
  if (raw == null) return null;
  final value = num.tryParse(raw);
  if (value == null || !value.isFinite || value < 0) {
    throw const FormatException('网页目录的集数无效。');
  }
  return value;
}

String? _label(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  return text.length <= 120 ? text : String.fromCharCodes(text.runes.take(120));
}
