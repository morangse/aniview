import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../../core/database/app_database.dart';
import '../../features/anime/anime.dart';
import 'animeko_rule_support.dart';
import 'catalog_source.dart';
import 'episode_matcher.dart';
import 'source_models.dart';

class AnimekoWebRule {
  const AnimekoWebRule._(this.origin, this.config);

  final Uri origin;
  final Map<String, dynamic> config;

  String get storage => jsonEncode(config);

  factory AnimekoWebRule.parse(Map<String, dynamic> raw) {
    final url = ruleText(raw['searchUrl'], '网页搜索地址');
    if (!url.contains('{keyword}')) {
      throw const FormatException('网页搜索地址缺少关键字。');
    }
    final probe = url.replaceAll('{keyword}', 'AniView');
    final origin = animekoOrigin(probe);
    if (url.split('/').take(3).join('/').contains('{keyword}') ||
        animekoPage(origin, origin, probe) == null) {
      throw const FormatException('网页搜索关键字必须在路径或查询参数中。');
    }
    final subject = raw['subjectFormatId'];
    final subjectKey = switch (subject) {
      'a' => 'selectorSubjectFormatA',
      'indexed' => 'selectorSubjectFormatIndexed',
      'json-path-indexed' => 'selectorSubjectFormatJsonPathIndexed',
      _ => throw const FormatException('网页搜索结果格式暂不兼容。'),
    };
    final subjectRule = ruleObject(raw[subjectKey], '搜索选择器');
    final subjectFields = switch (subject) {
      'a' => {'selectLists': _selector(subjectRule['selectLists'])},
      'indexed' => {
        'selectNames': _selector(subjectRule['selectNames']),
        'selectLinks': _selector(subjectRule['selectLinks']),
      },
      _ => {
        'selectNames': ruleJsonPath(subjectRule['selectNames'], '标题 JSONPath'),
        'selectLinks': ruleJsonPath(subjectRule['selectLinks'], '链接 JSONPath'),
      },
    };
    final channel = raw['channelFormatId'];
    final episodes = switch (channel) {
      'no-channel' => ruleObject(
        raw['selectorChannelFormatNoChannel'] ??
            raw['selectorChannelFormatFlattened'],
        '剧集选择器',
      ),
      'index-grouped' => ruleObject(
        raw['selectorChannelFormatIndexGrouped'] ??
            raw['selectorChannelFormatFlattened'],
        '线路剧集选择器',
      ),
      _ => throw const FormatException('网页线路格式暂不兼容。'),
    };
    final grouped = channel == 'index-grouped';
    final selectEpisodes = grouped
        ? episodes['selectEpisodesFromList'] ?? episodes['selectEpisodes']
        : episodes['selectEpisodes'] ?? episodes['selectEpisodesFromList'];
    final linkSelector = grouped
        ? episodes['selectEpisodeLinksFromList']
        : episodes['selectEpisodeLinks'];
    final fields = {
      if (grouped)
        'selectEpisodeLists': _selector(episodes['selectEpisodeLists']),
      (grouped ? 'selectEpisodesFromList' : 'selectEpisodes'): _selector(
        selectEpisodes,
      ),
      if (linkSelector is String && linkSelector.trim().isNotEmpty)
        (grouped ? 'selectEpisodeLinksFromList' : 'selectEpisodeLinks'):
            _selector(linkSelector),
    };
    return AnimekoWebRule._(origin, {
      'searchUrl': url,
      'subjectFormatId': subject,
      subjectKey: subjectFields,
      'channelFormatId': channel,
      (grouped
              ? 'selectorChannelFormatIndexGrouped'
              : 'selectorChannelFormatNoChannel'):
          fields,
    });
  }

  static String _selector(Object? value) {
    final selector = ruleText(value, 'CSS 选择器', limit: 300);
    try {
      html.parse('').querySelectorAll(selector);
    } on FormatException {
      throw const FormatException('CSS 选择器语法不受支持。');
    }
    return selector;
  }

  Uri searchUri(String keyword) {
    final url = (config['searchUrl'] as String).replaceAll(
      '{keyword}',
      Uri.encodeComponent(keyword),
    );
    final uri = animekoPage(origin, origin, url);
    if (uri != null) return uri;
    throw const FormatException('搜索地址超出网页来源。');
  }
}

typedef _WebResult = ({String title, String link, int? subjectId});

class AnimekoWebSource implements MediaSourceAdapter {
  const AnimekoWebSource(this.config, this.http);
  final ConfiguredSource config;
  final Dio http;

  AnimekoWebRule get _rule =>
      AnimekoWebRule.parse(ruleObject(jsonDecode(config.endpoint), '网页规则'));
  @override
  String get id => config.id;
  @override
  String get name => config.name;
  @override
  int get priority => config.priority;

  Iterable<_WebResult> _searchRows(AnimekoWebRule rule, String result) sync* {
    final data = rule.config;
    switch (data['subjectFormatId']) {
      case 'a':
        final selector = ruleObject(data['selectorSubjectFormatA'], '条目选择器');
        final page = html.parse(result);
        for (final item
            in page
                .querySelectorAll(selector['selectLists'] as String)
                .take(70)) {
          final link = _href(item);
          if (link != null) {
            yield (
              title: item.attributes['title'] ?? item.text,
              link: link,
              subjectId: animekoId(item.attributes['data-bangumi-subject']),
            );
          }
        }
      case 'indexed':
        final selector = ruleObject(
          data['selectorSubjectFormatIndexed'],
          '条目选择器',
        );
        final page = html.parse(result);
        final names = page.querySelectorAll(selector['selectNames'] as String);
        final links = page.querySelectorAll(selector['selectLinks'] as String);
        if (names.length != links.length) return;
        for (var i = 0; i < names.length && i < 70; i++) {
          final link = _href(links[i]);
          if (link != null) {
            yield (
              title: names[i].attributes['title'] ?? names[i].text,
              link: link,
              subjectId: animekoId(names[i].attributes['data-bangumi-subject']),
            );
          }
        }
      case 'json-path-indexed':
        final selector = ruleObject(
          data['selectorSubjectFormatJsonPathIndexed'],
          '条目选择器',
        );
        final body = jsonDecode(result);
        final names = animekoJsonPath(body, selector['selectNames'] as String);
        final links = animekoJsonPath(body, selector['selectLinks'] as String);
        if (names.length != links.length) return;
        for (var i = 0; i < names.length && i < 70; i++) {
          final title = names[i];
          final link = links[i];
          if (title is String && link is String) {
            yield (title: title, link: link, subjectId: null);
          }
        }
    }
  }

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final anime = request.anime;
    final episode = request.episode;
    if (anime == null ||
        episode == null ||
        anime.title.isEmpty ||
        anime.title.length > 240) {
      return [];
    }
    try {
      final rule = _rule;
      final search = rule.searchUri(anime.title);
      final text = await readCatalogText(
        http,
        search,
        cancelToken: cancelToken,
      );
      final names = [anime.title, anime.originalName, ...anime.aliases]
          .map(EpisodeMatcher.normalizeTitle)
          .where((name) => name.isNotEmpty)
          .toSet();
      final rows = _searchRows(rule, text).where(
        (row) => row.subjectId != null
            ? row.subjectId == anime.id
            : names.contains(EpisodeMatcher.normalizeTitle(row.title)),
      );
      final result = <SourceOffer>[];
      final seen = <Uri>{};
      for (final row in rows.take(2)) {
        final subject = animekoPage(rule.origin, search, row.link);
        if (subject == null) continue;
        final detail = html.parse(
          await readCatalogText(http, subject, cancelToken: cancelToken),
        );
        final loops = rule.config['channelFormatId'] == 'index-grouped';
        final config = ruleObject(
          rule.config[loops
              ? 'selectorChannelFormatIndexGrouped'
              : 'selectorChannelFormatNoChannel'],
          '剧集选择器',
        );
        final groups = loops
            ? detail
                  .querySelectorAll(config['selectEpisodeLists'] as String)
                  .take(12)
            : [detail.body ?? detail.documentElement!];
        for (final group in groups) {
          final blocks = group.querySelectorAll(
            config[loops ? 'selectEpisodesFromList' : 'selectEpisodes']
                as String,
          );
          final linkSelector =
              config[loops
                      ? 'selectEpisodeLinksFromList'
                      : 'selectEpisodeLinks']
                  as String?;
          final targets = linkSelector == null
              ? blocks
              : group.querySelectorAll(linkSelector);
          if (blocks.length != targets.length) continue;
          for (var i = 0; i < blocks.length && i < 512; i++) {
            final block = blocks[i];
            final text = (block.attributes['title'] ?? block.text).trim();
            final order = num.tryParse(
              block.attributes['data-episode-number'] ??
                  (_number.firstMatch(text)?.group(1) ?? ''),
            );
            final explicitEpisode = animekoId(
              block.attributes['data-bangumi-episode'],
            );
            final liveKind = _special.hasMatch(text)
                ? EpisodeKind.special
                : EpisodeKind.regular;
            final raw = _href(targets[i]);
            if (raw == null ||
                order != episode.number ||
                liveKind != episode.kind ||
                explicitEpisode != null && explicitEpisode != episode.id) {
              continue;
            }
            final target = animekoPage(rule.origin, subject, raw);
            if (target == null || !_canStore(target) || !seen.add(target)) {
              continue;
            }
            result.add(
              SourceOffer(
                sourceId: id,
                resourceId: animekoEncodeRecord([
                  target.path,
                  target.hasQuery ? target.query : null,
                ]),
                label: '$name · $text',
                subjectId: row.subjectId,
                episodeId: explicitEpisode,
                seriesTitle: row.title.trim(),
                number: order,
                kind: liveKind,
                priority: priority,
              ),
            );
            break;
          }
        }
      }
      return result;
    } on FormatException {
      throw const SourceIssue(SourceState.failed, '网页规则或站点响应不兼容。');
    }
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    try {
      final values = animekoDecodeRecord(resourceId, 2);
      final path = values[0];
      final query = values[1];
      if (path is! String ||
          !path.startsWith('/') ||
          (query != null && query is! String)) {
        throw const FormatException('无效的网页资源记录。');
      }
      final rule = _rule;
      final page = animekoPage(
        rule.origin,
        rule.origin,
        query == null ? path : '$path?$query',
      );
      if (page == null || !_canStore(page)) {
        throw const FormatException('播放页地址不合法。');
      }
      final direct = animekoMedia(rule.origin, page, page.toString());
      if (direct != null) return StreamAccess(direct, restrictOrigin: true);
      final text = await readCatalogText(http, page);
      final doc = html.parse(text);
      for (final element
          in doc.querySelectorAll('video[src], video source[src]').take(30)) {
        final raw = element.attributes['src'];
        if (raw == null) continue;
        final uri = animekoMedia(
          rule.origin,
          page,
          raw,
          mime: element.attributes['type'],
        );
        if (uri != null) return StreamAccess(uri, restrictOrigin: true);
      }
      for (final script in doc.querySelectorAll('script:not([src])').take(30)) {
        if (script.text.length > 16384) continue;
        final encoded = _plainPlayerData.firstMatch(script.text)?.group(1);
        if (encoded == null) continue;
        try {
          final data = jsonDecode(encoded);
          if (data is! Map ||
              (data['encrypt'] != 0 && data['encrypt'] != '0')) {
            continue;
          }
          final url = data['url'];
          final media = url is String
              ? animekoMedia(rule.origin, page, url)
              : null;
          if (media != null) return StreamAccess(media, restrictOrigin: true);
        } on FormatException {
          continue;
        }
      }
      throw const SourceIssue(
        SourceState.failed,
        '播放页未提供可直接解析的 MP4/HLS，可能需要网页播放器。',
      );
    } on FormatException {
      throw const SourceIssue(SourceState.failed, '网页播放地址或页面格式无效。');
    }
  }

  @override
  Future<void> testConnection() async {
    final rule = _rule;
    await readCatalogText(http, rule.searchUri('AniView'));
  }

  static final _number = RegExp(r'^(?:第\s*)?(\d{1,4}(?:\.\d+)?)\s*(?:[话話集]|$)');
  static final _special = RegExp(
    r'\b(?:sp|ova|oad)\b|特别篇|特典',
    caseSensitive: false,
  );
  static final _plainPlayerData = RegExp(
    r'\bplayer_[a-zA-Z0-9_]{1,32}\s*=\s*(\{[^\r\n]*?\})\s*(?:;|$)',
  );

  static String? _href(Element item) =>
      item.attributes['href'] ??
      item.querySelector('a[href]')?.attributes['href'];

  static bool _canStore(Uri page) =>
      page.toString().length <= 1200 &&
      !page.queryParameters.keys.any(
        (key) => RegExp(
          r'token|auth|secret|password|signature|key',
          caseSensitive: false,
        ).hasMatch(key),
      );
}
