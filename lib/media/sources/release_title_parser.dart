import '../../features/anime/anime.dart';

class ParsedRelease {
  const ParsedRelease({
    this.fansub,
    this.titles = const [],
    this.season,
    this.episode,
    this.kind,
    this.version,
    this.resolution,
    this.inferredWidth,
    this.codec,
    this.subtitleTags = const [],
    this.isBatch = false,
  });

  final String? fansub;
  final List<String> titles;
  final int? season;
  final num? episode;
  final EpisodeKind? kind;
  final int? version;
  final String? resolution;
  final int? inferredWidth;
  final String? codec;
  final List<String> subtitleTags;
  final bool isBatch;

  List<String> get displayTags => [
    ?fansub,
    ?resolution,
    ...subtitleTags.take(2),
    ?codec,
    if (isBatch) '合集',
  ];
}

class ReleaseTitleParser {
  const ReleaseTitleParser._();

  static final _bracketToken = RegExp(r'^[\[\(【（]([^\]\)】）]+)[\]\)】）]\s*');
  static final _anyBracket = RegExp(r'[\[\(【（]([^\]\)】）]+)[\]\)】）]');
  static final _fansubNoise = RegExp(
    r'^(?:(?:\d{1,2}月)?新番|搬运|合集|整理|转载|4k|2160p|1080p|720p|480p|'
    r'bdrip|webrip|web-dl|blu-?ray|hevc|x265|h\.?265|avc|x264|h\.?264|av1|'
    r'10bit|8bit|mp4|mkv|chs|cht|gb|big5|raw|aac|flac)$',
    caseSensitive: false,
  );

  static final _batchPattern = RegExp(
    r'(?:全\s*\d{1,3}\s*[话集話期]|\b(?:batch|complete)\b|合集|'
    r'(?:^|[\s\[\(【第\-])(\d{1,3})\s*[-~～]\s*(\d{1,3})(?=\s*(?:fin|end|[话集話]|[\]\)】\s]|$)))',
    caseSensitive: false,
  );

  static final _seasonPatterns = [
    RegExp(r'第\s*([1-9]\d?|[一二三四五六七八九十]+)\s*[季期部]'),
    RegExp(r'\bseason\s*(\d{1,2})\b', caseSensitive: false),
    RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)\s+season\b', caseSensitive: false),
    RegExp(r'\bpart\s*(\d{1,2})\b', caseSensitive: false),
    RegExp(r'\bs(\d{1,2})(?:\b|e\d)', caseSensitive: false),
  ];

  static final _specialTag = RegExp(
    r'(?:(?<![a-zA-Z0-9])(OVA|OAD|OAV|SP)(?![a-zA-Z0-9])|番外篇?|特别篇|总集篇|総集編)'
    r'(?:\s*[-#.]?\s*(\d{1,3}(?:\.5)?))?(?:v(\d))?',
    caseSensitive: false,
  );
  static final _sxxExx = RegExp(
    r'\bs\d{1,2}\s*e(\d{1,3}(?:\.5)?)(?:v(\d))?\b',
    caseSensitive: false,
  );
  static final _cnEpisode = RegExp(
    r'第\s*(\d{1,3}(?:\.5)?)\s*[话集話](?:v(\d))?',
    caseSensitive: false,
  );
  static final _epToken = RegExp(
    r'(?:^|[\s\-_\[【\(])ep?\s*(\d{1,3}(?:\.5)?)(?:v(\d))?(?=$|[\s\]】\)\._\-])',
    caseSensitive: false,
  );
  static final _bracketEpisode = RegExp(
    r'[\[\(【](\d{1,3}(?:\.5)?)(?:v(\d))?[\]\)】]',
    caseSensitive: false,
  );
  static final _dashEpisode = RegExp(
    r'(?:\s-\s|\s)(\d{1,3}(?:\.5)?)(?:v(\d))?(?=\s*(?:[\[\(【]|fin|end|\.[a-z0-9]{2,4}$|$))',
    caseSensitive: false,
  );

  static final _res2160 = RegExp(
    r'(?:\b2160p\b|\b4k\b|3840\s*[x×]\s*2160)',
    caseSensitive: false,
  );
  static final _res1080 = RegExp(
    r'(?:\b1080p\b|1920\s*[x×]\s*1080|\bfhd\b)',
    caseSensitive: false,
  );
  static final _res720 = RegExp(
    r'(?:\b720p\b|1280\s*[x×]\s*720)',
    caseSensitive: false,
  );
  static final _res480 = RegExp(r'\b480p\b', caseSensitive: false);

  static final _hevc = RegExp(
    r'(?:\bhevc\b|\bx265\b|\bh\.?265\b)',
    caseSensitive: false,
  );
  static final _av1 = RegExp(r'\bav1\b', caseSensitive: false);
  static final _avc = RegExp(
    r'(?:\bavc\b|\bx264\b|\bh\.?264\b)',
    caseSensitive: false,
  );

  static ParsedRelease parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const ParsedRelease();

    String? fansub;
    var rest = trimmed;
    while (true) {
      final m = _bracketToken.firstMatch(rest);
      if (m == null) break;
      final token = m.group(1)!.trim();
      rest = rest.substring(m.end);
      if (fansub == null &&
          token.isNotEmpty &&
          !_fansubNoise.hasMatch(token) &&
          !RegExp(r'^\d{1,4}(?:\.5)?(?:v\d)?$', caseSensitive: false).hasMatch(token)) {
        fansub = token;
      }
    }

    final (resolution, width) = _extractResolution(trimmed);
    final codec = _extractCodec(trimmed);
    final subtitleTags = _extractSubtitleTags(trimmed);
    final isBatch = _isBatchRelease(trimmed);
    final season = _extractSeason(trimmed);
    final (kind, episode, version) = _extractEpisode(
      trimmed,
      isBatch: isBatch,
      fansub: fansub,
    );
    final titles = _extractTitles(
      trimmed,
      fansub: fansub,
    );

    return ParsedRelease(
      fansub: fansub,
      titles: titles,
      season: season,
      episode: episode,
      kind: kind,
      version: version,
      resolution: resolution,
      inferredWidth: width,
      codec: codec,
      subtitleTags: subtitleTags,
      isBatch: isBatch,
    );
  }

  static (String?, int?) _extractResolution(String text) {
    if (_res2160.hasMatch(text)) return ('2160p', 3840);
    if (_res1080.hasMatch(text)) return ('1080p', 1920);
    if (_res720.hasMatch(text)) return ('720p', 1280);
    if (_res480.hasMatch(text)) return ('480p', 854);
    return (null, null);
  }

  static String? _extractCodec(String text) {
    if (_hevc.hasMatch(text)) return 'HEVC';
    if (_av1.hasMatch(text)) return 'AV1';
    if (_avc.hasMatch(text)) return 'AVC';
    return null;
  }

  static List<String> _extractSubtitleTags(String text) {
    final tags = <String>[];
    if (RegExp(r'简繁|chs\s*[&/_+]\s*cht|gb\s*[&/_+]\s*big5', caseSensitive: false)
        .hasMatch(text)) {
      tags.add('简繁');
    } else if (RegExp(r'简日|chs\s*[&/_+]\s*jp', caseSensitive: false)
        .hasMatch(text)) {
      tags.add('简日');
    } else if (RegExp(r'繁日|cht\s*[&/_+]\s*jp', caseSensitive: false)
        .hasMatch(text)) {
      tags.add('繁日');
    } else {
      if (RegExp(r'简中|简体|\bchs\b|\bgb\b', caseSensitive: false).hasMatch(text)) {
        tags.add('简中');
      }
      if (RegExp(r'繁中|繁体|\bcht\b|\bbig5\b', caseSensitive: false)
          .hasMatch(text)) {
        tags.add('繁中');
      }
    }
    if (text.contains('内封')) tags.add('内封');
    if (text.contains('内嵌')) tags.add('内嵌');
    if (text.contains('外挂')) tags.add('外挂');
    if (RegExp(r'生肉|\braw\b', caseSensitive: false).hasMatch(text)) {
      tags.add('生肉');
    }
    return List.unmodifiable(tags);
  }

  static bool _isBatchRelease(String text) {
    for (final m in _batchPattern.allMatches(text)) {
      final startStr = m.group(1);
      final endStr = m.group(2);
      if (startStr == null || endStr == null) return true;
      final start = int.tryParse(startStr);
      final end = int.tryParse(endStr);
      if (start != null && end != null && start < end && end <= 300) {
        return true;
      }
    }
    return false;
  }

  static int? _extractSeason(String text) {
    for (final pattern in _seasonPatterns) {
      final m = pattern.firstMatch(text);
      if (m == null) continue;
      final token = m.group(1) ?? '';
      final parsed = int.tryParse(token) ?? _parseChineseNumeral(token);
      if (parsed != null && parsed >= 1 && parsed <= 20) return parsed;
    }
    return null;
  }

  static int? _parseChineseNumeral(String token) {
    const map = {
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
    };
    if (map.containsKey(token)) return map[token];
    if (token.startsWith('十') && token.length == 2) {
      final ones = map[token[1]];
      if (ones != null) return 10 + ones;
    }
    return null;
  }

  static (EpisodeKind?, num?, int?) _extractEpisode(
    String text, {
    required bool isBatch,
    required String? fansub,
  }) {
    final search = fansub != null
        ? text.replaceFirst(fansub, '')
        : text;
    final special = _specialTag.firstMatch(search);
    if (special != null) {
      final number = num.tryParse(special.group(2) ?? '');
      final ver = int.tryParse(special.group(3) ?? '');
      return (EpisodeKind.special, number, ver);
    }
    if (isBatch) return (null, null, null);

    for (final pattern in [_sxxExx, _cnEpisode, _epToken, _bracketEpisode, _dashEpisode]) {
      for (final m in pattern.allMatches(search)) {
        final number = num.tryParse(m.group(1) ?? '');
        if (number == null || _isNonEpisodeNumber(search, m.start, m.end, number)) {
          continue;
        }
        final ver = int.tryParse(m.group(2) ?? '');
        return (EpisodeKind.regular, number, ver);
      }
    }
    return (null, null, null);
  }

  static bool _isNonEpisodeNumber(String text, int start, int end, num value) {
    if (value >= 1900 || value == 1080 || value == 720 || value == 480 || value == 2160) {
      return true;
    }
    final after = text.substring(end).toLowerCase();
    if (after.startsWith('bit') || after.startsWith('p') || after.startsWith('k')) {
      return true;
    }
    return false;
  }

  static List<String> _extractTitles(String text, {required String? fansub}) {
    var body = text.replaceFirst(
      RegExp(r'\.(?:mp4|mkv|avi|ts|flv|webm)$', caseSensitive: false),
      '',
    );
    if (fansub != null) {
      body = body.replaceFirst(
        RegExp('^\\s*[\\[\\(【（]${RegExp.escape(fansub)}[\\]\\)】）]\\s*'),
        '',
      );
    }
    // Strip trailing episode marker and everything after if separated cleanly.
    var stripped = body.replaceAll(_anyBracket, ' ').trim();
    stripped = stripped
        .replaceFirst(
          RegExp(
            r'(?:\s+-\s+|\s+)(?:s\d{1,2}e\d{1,3}|第\s*\d{1,3}(?:\.5)?\s*[话集話]|全\s*\d{1,3}\s*[话集話期]|ep?\s*\d{1,3}(?:\.5)?|\d{1,3}(?:\.5)?(?:\s*[-~～]\s*\d{1,3})?|(?:OVA|OAD|OAV|SP))(?:\s*v\d)?(?:\s.*|$)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'[\s\-_]+$'), '')
        .trim();

    if (stripped.length < 2) {
      for (final m in _anyBracket.allMatches(body)) {
        final inner = m.group(1)!.trim();
        if (inner.length < 2 ||
            inner == fansub ||
            _fansubNoise.hasMatch(inner) ||
            RegExp(r'^\d{1,4}(?:\.5)?(?:v\d)?$', caseSensitive: false).hasMatch(inner) ||
            _res1080.hasMatch(inner) ||
            _res720.hasMatch(inner) ||
            _res2160.hasMatch(inner) ||
            _hevc.hasMatch(inner) ||
            _extractSubtitleTags(inner).isNotEmpty) {
          continue;
        }
        stripped = inner;
        break;
      }
    }

    if (stripped.isEmpty) return const [];
    final parts = stripped
        .split(RegExp(r'\s*(?:/|／|\||｜)\s*'))
        .map((part) => part.replaceFirst(RegExp(r'[\s\-_]+$'), '').trim())
        .where((part) => part.length >= 2)
        .toSet()
        .toList(growable: false);
    return parts;
  }
}
