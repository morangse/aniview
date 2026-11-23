import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:xml/xml.dart';

import '../../core/database/app_database.dart';
import '../../core/database/secure_vault.dart';
import '../media.dart';
import '../sources/source_models.dart';
import '../sources/source_store.dart';

String decodeAttachment(List<int> bytes) {
  try {
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      if (bytes.length.isOdd) throw const FormatException();
      final little = bytes[0] == 0xff;
      return String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          little
              ? bytes[i] + (bytes[i + 1] << 8)
              : (bytes[i] << 8) + bytes[i + 1],
      ]);
    }
    final text = utf8.decode(bytes);
    if (text.contains('\x00')) throw const FormatException();
    return text.replaceFirst('\ufeff', '');
  } on FormatException {
    throw const FormatException('文件编码无法识别，请另存为 UTF-8 或带 BOM 的 UTF-16。');
  }
}

class ExternalAssSubtitle {
  const ExternalAssSubtitle({
    required this.id,
    required this.name,
    required this.payload,
  });

  final String id;
  final String name;
  final String payload;
}

class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class SubtitleManager {
  SubtitleManager._(this.cues, this._longest);
  final List<SubtitleCue> cues;
  final int _longest;
  static final _timestamp = RegExp(
    r'^(?:(\d{1,3}):)?(\d{2}):(\d{2})[.,](\d{3})$',
  );
  static final _timing = RegExp(r'^(\S+)\s+-->\s+(\S+)(?:\s|$)');
  static final _assDialogue = RegExp(
    r'^\s*dialogue\s*:',
    multiLine: true,
    caseSensitive: false,
  );

  static bool isAssFilename(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.ass') || lower.endsWith('.ssa');
  }

  static void validateAss(String contents, String filename) {
    if (!isAssFilename(filename)) {
      throw const FormatException('请选择 SRT、WebVTT 或 ASS/SSA 字幕。');
    }
    final normalized = contents.replaceFirst('\ufeff', '');
    final lower = normalized.toLowerCase();
    final hasSection =
        lower.contains('[script info]') || lower.contains('[events]');
    if (!hasSection || !_assDialogue.hasMatch(normalized)) {
      throw const FormatException('未识别到有效的 ASS / SSA 字幕内容。');
    }
  }

  factory SubtitleManager.parse(String contents, String filename) {
    final lower = filename.toLowerCase();
    if (!lower.endsWith('.srt') && !lower.endsWith('.vtt')) {
      throw const FormatException('请选择 SRT 或 WebVTT 字幕。');
    }
    final lines = const LineSplitter().convert(
      contents.replaceFirst('\ufeff', ''),
    );
    if (lower.endsWith('.vtt') &&
        (lines.isEmpty || !lines.first.startsWith('WEBVTT'))) {
      throw const FormatException('WebVTT 文件缺少 WEBVTT 文件头。');
    }
    final cues = <SubtitleCue>[];
    var longest = 0;
    for (var i = 0; i < lines.length; i++) {
      final timing = _timing.firstMatch(lines[i].trim());
      if (timing == null) continue;
      final start = _millis(timing.group(1)!);
      final end = _millis(timing.group(2)!);
      final body = <String>[];
      while (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
        body.add(lines[++i]);
      }
      final text = body
          .join('\n')
          .replaceAll(RegExp(r'</?[a-zA-Z][^>\r\n]*>'), '')
          .trim();
      if (start == null || end == null || end <= start || text.isEmpty) {
        continue;
      }
      if (end - start > longest) longest = end - start;
      cues.add(
        SubtitleCue(
          start,
          end,
          text.length > 1200 ? text.substring(0, 1200) : text,
        ),
      );
      if (cues.length >= 30000) break;
    }
    if (cues.isEmpty) throw const FormatException('没有识别到可用的字幕行。');
    cues.sort((a, b) => a.start.compareTo(b.start));
    return SubtitleManager._(List.unmodifiable(cues), longest);
  }

  String textAt(Duration position, {int offsetMs = 0}) {
    final adjusted = position.inMilliseconds - offsetMs;
    final first = lowerBound(cues, adjusted - _longest, (cue) => cue.start);
    return cues
        .skip(first)
        .takeWhile((cue) => cue.start <= adjusted)
        .where((cue) => cue.end > adjusted)
        .map((cue) => cue.text)
        .take(4)
        .join('\n');
  }

  static int? _millis(String value) {
    final match = _timestamp.firstMatch(value);
    if (match == null) return null;
    final hours = int.parse(match.group(1) ?? '0');
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    if (minutes >= 60 && match.group(1) != null || seconds >= 60) return null;
    return ((hours * 60 + minutes) * 60 + seconds) * 1000 +
        int.parse(match.group(4)!);
  }

  static String stem(String name) => name
      .toLowerCase()
      .replaceFirst(RegExp(r'\.[a-z0-9]+$'), '')
      .replaceFirst(
        RegExp(r'[._-](zh-hans|zh-hant|chs|cht|eng|jpn|en|ja|zh)$'),
        '',
      );
}

enum DanmakuMode { scroll, top, bottom }

class DanmakuItem {
  const DanmakuItem(
    this.start,
    this.mode,
    this.text, {
    this.color = 0xFFFFFFFF,
  });
  final int start;
  final DanmakuMode mode;
  final String text;
  final int color;
}

class DanmakuTrack {
  const DanmakuTrack(this.items);
  final List<DanmakuItem> items;

  static int _parseColor(Object? raw) {
    if (raw is int && raw >= 0 && raw <= 0xFFFFFF) {
      return 0xFF000000 | raw;
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.startsWith('#')) {
        final hex = int.tryParse(value.substring(1), radix: 16);
        if (hex != null && value.length == 7) {
          return 0xFF000000 | hex;
        }
      } else {
        final dec = int.tryParse(value);
        if (dec != null && dec >= 0 && dec <= 0xFFFFFF) {
          return 0xFF000000 | dec;
        }
      }
    }
    return 0xFFFFFFFF;
  }

  factory DanmakuTrack.parse(String input, String filename) {
    final items = <DanmakuItem>[];
    void add(Object? time, Object? mode, Object? content, {Object? color}) {
      final seconds = double.tryParse('$time');
      if (seconds == null ||
          !seconds.isFinite ||
          seconds < 0 ||
          seconds > 86400 ||
          content is! String ||
          content.trim().isEmpty) {
        return;
      }
      final placement = switch ('$mode') {
        '0' || '1' || '2' || '3' || 'scroll' => DanmakuMode.scroll,
        '5' || 'top' => DanmakuMode.top,
        '4' || 'bottom' => DanmakuMode.bottom,
        _ => null,
      };
      if (placement == null) return;
      final text = content.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
      items.add(
        DanmakuItem(
          (seconds * 1000).round(),
          placement,
          String.fromCharCodes(text.runes.take(180)),
          color: _parseColor(color),
        ),
      );
    }

    try {
      final extension = filename.toLowerCase();
      if (extension.endsWith('.xml')) {
        if (input.toUpperCase().contains('<!DOCTYPE')) {
          throw const FormatException();
        }
        final xml = XmlDocument.parse(input);
        for (final node in xml.findAllElements('d').take(30000)) {
          final params = node.getAttribute('p')?.split(',');
          if (params != null && params.length >= 2) {
            add(
              params[0],
              params[1],
              node.innerText,
              color: params.length >= 4 ? params[3] : null,
            );
          }
        }
      } else if (extension.endsWith('.json')) {
        final decoded = jsonDecode(input);
        final rows = decoded is Map
            ? (decoded['items'] ?? decoded['comments'])
            : decoded;
        if (rows is! List) throw const FormatException();
        for (final row in rows.whereType<Map>().take(30000)) {
          final rawParams = row['p'];
          final rawMsg = row['m'];
          if (rawParams is String && rawMsg is String) {
            final params = rawParams.split(',');
            if (params.length >= 2) {
              add(
                params[0],
                params[1],
                rawMsg,
                color: params.length >= 3 ? params[2] : null,
              );
            }
          } else {
            add(row['time'], row['mode'], row['text'], color: row['color']);
          }
        }
      } else {
        throw const FormatException();
      }
    } on Exception {
      throw const FormatException('无法识别弹幕文件。支持本地 XML 或 JSON。');
    }
    if (items.isEmpty) throw const FormatException('文件中没有可显示的弹幕。');
    return DanmakuTrack(items..sort((a, b) => a.start.compareTo(b.start)));
  }

  static String encodeJson(List<DanmakuItem> items) => jsonEncode([
    for (final item in items)
      {
        'time': double.parse((item.start / 1000).toStringAsFixed(3)),
        'mode': item.mode.name,
        'text': item.text,
        'color':
            '#${(item.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      },
  ]);

  Iterable<(int, DanmakuItem)> visibleIndexed(
    int ms,
    int lifetime,
    int limit,
    List<String> blocked, {
    bool showScroll = true,
    bool showTop = true,
    bool showBottom = true,
  }) sync* {
    final start = lowerBound(items, ms - lifetime, (item) => item.start);
    var count = 0;
    for (var index = start; index < items.length && count < limit; index++) {
      final item = items[index];
      if (item.start > ms) break;
      final allowed = switch (item.mode) {
        DanmakuMode.scroll => showScroll,
        DanmakuMode.top => showTop,
        DanmakuMode.bottom => showBottom,
      };
      if (!allowed) continue;
      final text = item.text.toLowerCase();
      if (blocked.any((word) => text.contains(word.toLowerCase()))) continue;
      yield (index, item);
      count++;
    }
  }

  Iterable<DanmakuItem> visible(
    int ms,
    int lifetime,
    int limit,
    List<String> blocked,
  ) => visibleIndexed(ms, lifetime, limit, blocked).map((entry) => entry.$2);
}

int lowerBound<T>(List<T> values, int target, int Function(T) key) {
  var lo = 0;
  var hi = values.length;
  while (lo < hi) {
    final mid = lo + (hi - lo) ~/ 2;
    if (key(values[mid]) < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

class OverlaySettings {
  const OverlaySettings({
    this.subtitleId,
    this.subtitleOffset = 0,
    this.subtitleSize = 18,
    this.subtitlePosition = .86,
    this.subtitleShadow = true,
    this.subtitleOutline = true,
    this.danmakuId,
    this.danmakuEnabled = false,
    this.danmakuOpacity = .78,
    this.danmakuSpeed = 1,
    this.danmakuSize = 16,
    this.danmakuOffset = 0,
    this.danmakuLimit = 24,
    this.danmakuArea = 0.5,
    this.danmakuShowScroll = true,
    this.danmakuShowTop = true,
    this.danmakuShowBottom = true,
    this.danmakuShowColor = true,
    this.blocked = const [],
  });

  final String? subtitleId;
  final int subtitleOffset;
  final double subtitleSize;
  final double subtitlePosition;
  final bool subtitleShadow;
  final bool subtitleOutline;
  final String? danmakuId;
  final bool danmakuEnabled;
  final double danmakuOpacity;
  final double danmakuSpeed;
  final double danmakuSize;
  final int danmakuOffset;
  final int danmakuLimit;
  final double danmakuArea;
  final bool danmakuShowScroll;
  final bool danmakuShowTop;
  final bool danmakuShowBottom;
  final bool danmakuShowColor;
  final List<String> blocked;

  factory OverlaySettings.fromJson(Map<String, dynamic> value) =>
      OverlaySettings(
        subtitleId: value['subtitleId'] as String?,
        subtitleOffset: value['subtitleOffset'] as int? ?? 0,
        subtitleSize: (value['subtitleSize'] as num? ?? 18).toDouble().clamp(
          12,
          32,
        ),
        subtitlePosition: (value['subtitlePosition'] as num? ?? .86)
            .toDouble()
            .clamp(.08, .94),
        subtitleShadow: value['subtitleShadow'] != false,
        subtitleOutline: value['subtitleOutline'] != false,
        danmakuId: value['danmakuId'] as String?,
        danmakuEnabled: value['danmakuEnabled'] == true,
        danmakuOpacity: (value['danmakuOpacity'] as num? ?? .78)
            .toDouble()
            .clamp(.1, 1),
        danmakuSpeed: (value['danmakuSpeed'] as num? ?? 1).toDouble().clamp(
          .6,
          1.7,
        ),
        danmakuSize: (value['danmakuSize'] as num? ?? 16).toDouble().clamp(
          12,
          28,
        ),
        danmakuOffset: value['danmakuOffset'] as int? ?? 0,
        danmakuLimit: (value['danmakuLimit'] as int? ?? 24).clamp(4, 60),
        danmakuArea: (value['danmakuArea'] as num? ?? .5).toDouble().clamp(
          .2,
          1.0,
        ),
        danmakuShowScroll: value['danmakuShowScroll'] != false,
        danmakuShowTop: value['danmakuShowTop'] != false,
        danmakuShowBottom: value['danmakuShowBottom'] != false,
        danmakuShowColor: value['danmakuShowColor'] != false,
        blocked: (value['blocked'] as List? ?? const [])
            .whereType<String>()
            .take(100)
            .toList(),
      );

  Map<String, Object?> toJson() => {
    'subtitleId': subtitleId,
    'subtitleOffset': subtitleOffset,
    'subtitleSize': subtitleSize,
    'subtitlePosition': subtitlePosition,
    'subtitleShadow': subtitleShadow,
    'subtitleOutline': subtitleOutline,
    'danmakuId': danmakuId,
    'danmakuEnabled': danmakuEnabled,
    'danmakuOpacity': danmakuOpacity,
    'danmakuSpeed': danmakuSpeed,
    'danmakuSize': danmakuSize,
    'danmakuOffset': danmakuOffset,
    'danmakuLimit': danmakuLimit,
    'danmakuArea': danmakuArea,
    'danmakuShowScroll': danmakuShowScroll,
    'danmakuShowTop': danmakuShowTop,
    'danmakuShowBottom': danmakuShowBottom,
    'danmakuShowColor': danmakuShowColor,
    'blocked': blocked,
  };
}

class OverlayBundle {
  const OverlayBundle(
    this.settings,
    this.files,
    this.subtitle,
    this.danmaku, {
    this.assSubtitle,
  });
  final OverlaySettings settings;
  final List<EpisodeAttachment> files;
  final SubtitleManager? subtitle;
  final DanmakuTrack? danmaku;
  final ExternalAssSubtitle? assSubtitle;
}

class OverlayStore {
  const OverlayStore(this.store);
  final SourceStore store;

  Future<OverlayBundle> load(MediaCandidate media) async {
    final key = watchAssetKey(media);
    final rows = await (store.db.select(
      store.db.episodeAttachments,
    )..where((row) => row.episodeKey.equals(key))).get();
    final saved = await store.preference('overlay.$key');
    final settings = saved == null
        ? const OverlaySettings()
        : OverlaySettings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    final match = settings.subtitleId == null
        ? null
        : rows
              .where(
                (row) =>
                    row.kind == 'subtitle' && row.id == settings.subtitleId,
              )
              .firstOrNull;
    final danmaku = rows
        .where((row) => row.kind == 'danmaku' && row.id == settings.danmakuId)
        .firstOrNull;
    final isAss = match != null && SubtitleManager.isAssFilename(match.name);
    return OverlayBundle(
      settings,
      rows,
      match == null || isAss
          ? null
          : SubtitleManager.parse(match.payload, match.name),
      danmaku == null
          ? null
          : DanmakuTrack.parse(danmaku.payload, danmaku.name),
      assSubtitle: isAss
          ? ExternalAssSubtitle(
              id: match.id,
              name: match.name,
              payload: match.payload,
            )
          : null,
    );
  }

  Future<EpisodeAttachment> add(
    MediaCandidate media,
    String kind,
    String filename,
    List<int> bytes,
  ) async {
    final text = decodeAttachment(bytes);
    if (kind == 'subtitle') {
      if (SubtitleManager.isAssFilename(filename)) {
        SubtitleManager.validateAss(text, filename);
      } else {
        SubtitleManager.parse(text, filename);
      }
    } else {
      DanmakuTrack.parse(text, filename);
    }
    final attachment = EpisodeAttachment(
      id: randomIdentifier(12),
      episodeKey: watchAssetKey(media),
      kind: kind,
      name: filename,
      payload: text,
    );
    await store.db.into(store.db.episodeAttachments).insert(attachment);
    return attachment;
  }

  Future<EpisodeAttachment> saveDanmakuPayload(
    MediaCandidate media,
    String filename,
    String payload,
  ) async {
    DanmakuTrack.parse(payload, filename);
    final attachment = EpisodeAttachment(
      id: randomIdentifier(12),
      episodeKey: watchAssetKey(media),
      kind: 'danmaku',
      name: filename,
      payload: payload,
    );
    await store.db.into(store.db.episodeAttachments).insert(attachment);
    return attachment;
  }

  Future<EpisodeAttachment> appendLocalDanmaku(
    MediaCandidate media,
    DanmakuItem item, {
    String? currentDanmakuId,
  }) async {
    final key = watchAssetKey(media);
    final rows = (await (store.db.select(
      store.db.episodeAttachments,
    )..where((row) => row.episodeKey.equals(key)))
        .get())
        .where((row) => row.kind == 'danmaku')
        .toList();
    final existing = currentDanmakuId == null
        ? rows.firstOrNull
        : rows.where((row) => row.id == currentDanmakuId).firstOrNull;
    final items = <DanmakuItem>[
      if (existing != null) ...DanmakuTrack.parse(existing.payload, existing.name).items,
      item,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final encoded = DanmakuTrack.encodeJson(items);
    if (existing != null) {
      final nextName = existing.name.toLowerCase().endsWith('.json')
          ? existing.name
          : '${existing.name}.json';
      await (store.db.update(
        store.db.episodeAttachments,
      )..where((row) => row.id.equals(existing.id))).write(
        EpisodeAttachmentsCompanion(
          name: Value(nextName),
          payload: Value(encoded),
        ),
      );
      return EpisodeAttachment(
        id: existing.id,
        episodeKey: existing.episodeKey,
        kind: existing.kind,
        name: nextName,
        payload: encoded,
      );
    }
    final created = EpisodeAttachment(
      id: randomIdentifier(12),
      episodeKey: key,
      kind: 'danmaku',
      name: '本地弹幕.json',
      payload: encoded,
    );
    await store.db.into(store.db.episodeAttachments).insert(created);
    return created;
  }

  Future<({bool hasTrack, bool enabled})> toggleDanmakuQuick(
    MediaCandidate media,
  ) async {
    final bundle = await load(media);
    final firstDanmaku = bundle.files
        .where((row) => row.kind == 'danmaku')
        .firstOrNull;
    if (bundle.danmaku == null && firstDanmaku == null) {
      return (hasTrack: false, enabled: bundle.settings.danmakuEnabled);
    }
    final next = !bundle.settings.danmakuEnabled;
    final nextId = bundle.settings.danmakuId ?? firstDanmaku?.id;
    await save(media, {
      ...bundle.settings.toJson(),
      'danmakuId': nextId,
      'danmakuEnabled': next,
    });
    return (hasTrack: true, enabled: next);
  }

  Future<void> save(MediaCandidate media, Map<String, Object?> settings) =>
      store.setPreference(
        'overlay.${watchAssetKey(media)}',
        jsonEncode(settings),
      );
}
