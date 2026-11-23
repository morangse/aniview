import '../../features/anime/anime.dart';
import 'release_title_parser.dart';
import 'source_models.dart';

class EpisodeMatcher {
  const EpisodeMatcher();

  MatchEvidence evaluate(MediaSearchRequest request, SourceOffer offer) {
    final series = request.anime;
    final parsed = ReleaseTitleParser.parse(offer.label);
    final tags = parsed.displayTags;

    MatchEvidence build(
      int score,
      List<String> reasons, {
      bool verified = false,
      bool rejected = false,
    }) => MatchEvidence(
      score,
      reasons.join(' · '),
      verified: verified,
      rejected: rejected,
      tags: tags,
      reasons: List.unmodifiable(reasons),
      fansub: parsed.fansub,
      resolution: parsed.resolution,
      inferredWidth: parsed.inferredWidth,
      isBatch: parsed.isBatch,
      version: parsed.version,
    );

    if (series == null) {
      return build(100, const ['个人片源'], verified: true);
    }

    final seriesParsed =
        offer.seriesTitle != null && offer.seriesTitle != offer.label
        ? ReleaseTitleParser.parse(offer.seriesTitle!)
        : null;
    final effectiveNumber =
        offer.number ?? (parsed.isBatch ? null : parsed.episode);
    final effectiveKind = offer.kind ?? parsed.kind;
    final effectiveSeason = offer.season ?? parsed.season ?? seriesParsed?.season;
    final episode = request.episode;

    if (offer.subjectId != null && offer.subjectId != series.id) {
      return build(0, const ['Bangumi 条目 ID 不符'], rejected: true);
    }
    if (episode != null) {
      if (offer.episodeId != null && offer.episodeId != episode.id) {
        return build(0, const ['剧集 ID 不符'], rejected: true);
      }
      if (effectiveKind != null && effectiveKind != episode.kind) {
        return build(0, const ['正片与特别篇类型不符'], rejected: true);
      }
      if (effectiveNumber != null && effectiveNumber != episode.number) {
        return build(0, const ['集数不符'], rejected: true);
      }
    }

    final names = [series.chineseName, series.originalName, ...series.aliases];
    final seasons = names.map(seasonHint).nonNulls.toSet();
    if (effectiveSeason != null &&
        seasons.length == 1 &&
        !seasons.contains(effectiveSeason)) {
      return build(0, const ['季度不符'], rejected: true);
    }

    if (offer.subjectId == series.id &&
        (episode == null || offer.episodeId == episode.id)) {
      return build(100, ['条目和目标剧集的本地绑定', ...tags], verified: true);
    }
    if (episode != null &&
        offer.subjectId == series.id &&
        offer.numberedWithinSubject &&
        effectiveNumber == episode.number &&
        effectiveKind == episode.kind) {
      return build(96, ['Bangumi 条目 ID、集数和剧集类型一致', ...tags], verified: true);
    }
    if (episode != null &&
        offer.numberedWithinSubject &&
        effectiveNumber == episode.number &&
        effectiveKind == episode.kind &&
        _sameRelease(series, offer)) {
      return build(94, ['中文名、原名、年份、总集数与当前剧集一致', ...tags], verified: true);
    }

    final normalizedNames = names.map(normalizeTitle).where((s) => s.isNotEmpty).toSet();
    final strippedNames = names
        .map(stripSeasonTitle)
        .map(normalizeTitle)
        .where((s) => s.isNotEmpty)
        .toSet();
    final candidateTitles = <String>[
      if (offer.seriesTitle != null && offer.seriesTitle!.isNotEmpty)
        offer.seriesTitle!,
      ...parsed.titles,
      ...?seriesParsed?.titles,
    ];

    var exactFull = false;
    var exactStripped = false;
    for (final rawTitle in candidateTitles) {
      final norm = normalizeTitle(rawTitle);
      if (norm.isEmpty) continue;
      if (normalizedNames.contains(norm)) {
        exactFull = true;
        break;
      }
      if (strippedNames.contains(normalizeTitle(stripSeasonTitle(rawTitle)))) {
        exactStripped = true;
      }
    }

    final exact = exactFull || exactStripped;
    if (!exact && offer.subjectId == null) {
      return build(25, ['片源标题未能与原名或别名完全对应']);
    }

    final reasons = <String>[
      exactFull ? '标题精确命中' : '主标题命中',
    ];
    if (parsed.isBatch && episode != null && offer.episodeId == null) {
      reasons.add('识别为合集资源');
      reasons.add('首次需确认是否作单集播放');
      return build(42, reasons);
    }
    if (episode == null) {
      reasons.add('请确认要播放的剧集');
      return build(50, reasons);
    }
    if (effectiveNumber == null || effectiveKind == null) {
      reasons.add('片源缺少明确集数或类型');
      return build(55, reasons);
    }

    final epLabel = effectiveKind == EpisodeKind.special
        ? '特别篇 $effectiveNumber'
        : '第$effectiveNumber话一致';
    reasons.add(epLabel);
    if (parsed.version != null && parsed.version! >= 2) {
      reasons.add('v${parsed.version} 修订版');
    }
    if (parsed.resolution != null) reasons.add(parsed.resolution!);

    if (effectiveSeason == null && seasons.isNotEmpty) {
      reasons.add('季度待确认');
      return build(65, reasons);
    }
    if (effectiveSeason == null && seasons.length > 1) {
      reasons.add('季度待确认');
      return build(65, reasons);
    }
    if (seasons.length == 1 && effectiveSeason != null) {
      reasons.add('第$effectiveSeason季一致');
    }
    reasons.add('首次需确认');
    return build(86, reasons);
  }

  static String normalizeTitle(String value) {
    final ascii = String.fromCharCodes(
      value.runes.map(
        (code) => code >= 0xff01 && code <= 0xff5e ? code - 0xfee0 : code,
      ),
    );
    return ascii.toLowerCase().replaceAll(
      RegExp(r'[\s\u3000·・!！?？:：\-_./／()（）【】\[\]「」『』]+'),
      '',
    );
  }

  static String stripSeasonTitle(String value) => value
      .replaceAll(
        RegExp(
          r'(?:第\s*(?:\d{1,2}|[一二三四五六七八九十]+)\s*[季期部]|season\s*\d{1,2}|\d{1,2}(?:st|nd|rd|th)\s+season|part\s*\d{1,2}|\bs\d{1,2}\b)',
          caseSensitive: false,
        ),
        ' ',
      )
      .trim();

  static bool _sameRelease(AnimeSubject anime, SourceOffer offer) {
    final primary = normalizeTitle(anime.chineseName);
    final original = normalizeTitle(anime.originalName);
    final year = int.tryParse(anime.year ?? '');
    return primary.isNotEmpty &&
        original.isNotEmpty &&
        primary != original &&
        offer.seriesEpisodeCount != null &&
        anime.episodeCount == offer.seriesEpisodeCount &&
        year != null &&
        year == offer.seriesYear &&
        primary == normalizeTitle(offer.seriesTitle ?? '') &&
        original == normalizeTitle(offer.seriesOriginalTitle ?? '');
  }

  static final _season = RegExp(
    r'(?:第\s*(\d{1,2})\s*[季期部]|season\s*(\d{1,2})\b|\bs(\d{1,2})(?:\b|e\d)|(\d{1,2})(?:st|nd|rd|th)\s+season)',
    caseSensitive: false,
  );

  static int? seasonHint(String text) {
    final match = _season.firstMatch(text);
    if (match == null) return null;
    return int.tryParse(
      match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
    );
  }
}
