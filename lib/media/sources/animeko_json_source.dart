import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/database/app_database.dart';
import '../../features/anime/anime.dart';
import 'animeko_rule_support.dart';
import 'catalog_source.dart';
import 'episode_matcher.dart';
import 'source_models.dart';

class AnimekoJsonRule {
  AnimekoJsonRule._(
    this.origin,
    this._search,
    this._subject,
    this._play,
    this.headers,
    this.interval,
  );

  final Uri origin;
  final _JsonStage _search;
  final _JsonStage _subject;
  final _JsonStage _play;
  final Map<String, String> headers;
  final Duration interval;

  String get storage => jsonEncode({
    'baseUrl': origin.toString(),
    'headers': headers.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n'),
    'requestInterval': interval.inMilliseconds,
    'search': _search.data,
    'subject': _subject.data,
    'play': _play.data,
  });

  factory AnimekoJsonRule.parse(Map<String, dynamic> config) {
    final origin = animekoOrigin(ruleText(config['baseUrl'], 'API 基础地址'));
    final headers = _publicHeaders(config['headers']);
    final search = _JsonStage.parse(config['search'], origin, '搜索', [
      'selectItems',
      'selectName',
      'selectId',
    ]);
    final subjectConfig = ruleObject(config['subject'], '剧集规则');
    final subject = _JsonStage.parse(subjectConfig, origin, '剧集', []);
    if (subjectConfig['channelFormatId'] != 'grouped') {
      throw const FormatException('当前支持 grouped JSON 线路。');
    }
    final grouped = ruleObject(subjectConfig['channelFormatGrouped'], '分组线路');
    final episodes = ruleObject(subjectConfig['episodes'], '剧集规则');
    subject.data['channelFormatId'] = 'grouped';
    subject.data['channelFormatGrouped'] = _paths(grouped, [
      'selectChannels',
      'selectChannelName',
    ]);
    subject.data['episodes'] = {
      ..._paths(episodes, [
        'selectEpisodes',
        'selectName',
        'selectId',
        'selectSort',
        'selectType',
      ]),
      if (episodes['typeMapping'] != null)
        'typeMapping': ruleText(episodes['typeMapping'], '剧集类型表', limit: 512),
    };
    final play = _JsonStage.parse(config['play'], origin, '播放', [
      'selectCandidates',
      'selectCandidateChannel',
      'selectVideoUrl',
    ]);
    final delay = config['requestInterval'];
    final interval = Duration(
      milliseconds: delay is int ? delay.clamp(0, 2000) : 0,
    );
    return AnimekoJsonRule._(origin, search, subject, play, headers, interval);
  }
}

class _JsonStage {
  _JsonStage(this.data, this.url, this.method, this.body);
  final Map<String, dynamic> data;
  final String url;
  final String method;
  final String? body;

  factory _JsonStage.parse(
    Object? value,
    Uri origin,
    String label,
    List<String> fields,
  ) {
    final config = ruleObject(value, '$label规则');
    final request = ruleObject(config['request'], '$label请求');
    final url = ruleText(request['url'], '$label地址');
    final method = request['method'] ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      throw const FormatException('API 模板仅支持 GET 和 POST。');
    }
    final phaseHeaders = request['headers'];
    if (phaseHeaders is String && phaseHeaders.trim().isNotEmpty ||
        phaseHeaders is Map && phaseHeaders.isNotEmpty) {
      throw const FormatException('此规则需要单阶段请求头。');
    }
    final body = request['body'];
    if (body != null &&
        (body is! String ||
            body.length > 4096 ||
            method == 'GET' && body.trim().isNotEmpty)) {
      throw const FormatException('API 请求体格式无效。');
    }
    if (animekoPage(origin, origin, _renderUrl(url, _templateSample)) == null) {
      throw const FormatException('所有 API 请求必须沿用已导入的来源地址。');
    }
    if (url.contains('://') &&
        _templateVariable.hasMatch(url.split('/').take(3).join('/'))) {
      throw const FormatException('API 主机不能使用模板变量。');
    }
    if (body is String && body.trim().isNotEmpty) {
      _renderBody(body, _templateSample);
    }
    return _JsonStage(
      {
        'request': {'url': url, 'method': method, 'body': ?body},
        ..._paths(config, fields),
      },
      url,
      method as String,
      body as String?,
    );
  }

  Future<Object?> load(
    AnimekoJsonRule rule,
    Dio http,
    Map<String, Object> values,
    CancelToken? token,
  ) async {
    final uri = animekoPage(rule.origin, rule.origin, _renderUrl(url, values));
    if (uri == null) throw const FormatException('API 地址超出来源范围。');
    final payload = body;
    final text = await readCatalogText(
      http,
      uri,
      method: method,
      data: payload == null || payload.trim().isEmpty
          ? null
          : _renderBody(payload, values),
      cancelToken: token,
      headers: {
        ...rule.headers,
        'accept': 'application/json',
        if (method == 'POST') 'content-type': 'application/json',
      },
    );
    return jsonDecode(text);
  }
}

Map<String, String> _paths(Map<String, dynamic> config, List<String> keys) => {
  for (final key in keys) key: ruleJsonPath(config[key], key),
};

final _templateVariable = RegExp(r'\{([a-zA-Z][a-zA-Z0-9]*)\}');
final _bodyToken = RegExp(r'"(?:[^"\\]|\\.)*"|\{([a-zA-Z][a-zA-Z0-9]*)\}');
const _templateSample = <String, Object>{
  'keyword': 'AniView',
  'page': 1,
  'pageSize': 20,
  'id': 1,
  'subjectId': 1,
  'episodeId': 1,
  'channel': 'line',
};

Object _value(String key, Map<String, Object> values) {
  final val = values[key];
  if (val != null) return val;
  throw const FormatException('存在未知的请求变量。');
}

String _renderUrl(String template, Map<String, Object> values) =>
    template.replaceAllMapped(
      _templateVariable,
      (match) =>
          Uri.encodeComponent(_value(match.group(1)!, values).toString()),
    );

String _renderBody(String template, Map<String, Object> values) {
  final result = template.replaceAllMapped(_bodyToken, (token) {
    if (token.group(1) case final key?) return jsonEncode(_value(key, values));
    final quoted = jsonDecode(token.group(0)!) as String;
    return jsonEncode(
      quoted.replaceAllMapped(
        _templateVariable,
        (match) => _value(match.group(1)!, values).toString(),
      ),
    );
  });
  final body = jsonDecode(result);
  if (body is! Map) throw const FormatException('API 请求体应为 JSON 对象。');
  return jsonEncode(body);
}

Map<String, String> _publicHeaders(Object? raw) {
  if (raw == null || raw == '') return const {};
  if (raw is! String || raw.length > 2048) {
    throw const FormatException('API 请求头格式无效。');
  }
  final headers = <String, String>{};
  for (final line in const LineSplitter().convert(raw)) {
    if (line.trim().isEmpty) continue;
    final colon = line.indexOf(':');
    if (colon < 1) throw const FormatException('API 请求头格式无效。');
    final key = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    if (value.isEmpty ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
        headers.containsKey(key) ||
        !const {
          'origin',
          'accept',
          'user-agent',
          'apikey',
          'authorization',
        }.contains(key)) {
      throw const FormatException('此 API 规则含有未支持的请求头。');
    }
    if (key == 'origin' && animekoOrigin(value).toString() != value) {
      throw const FormatException('API Origin 格式无效。');
    }
    headers[key] = value;
  }
  final apiKey = headers['apikey'];
  final auth = headers['authorization'];
  if ((apiKey != null || auth != null) &&
      (apiKey == null ||
          !RegExp(r'^sb_publishable_[a-zA-Z0-9_-]{8,100}$').hasMatch(apiKey) ||
          auth != null && auth != 'Bearer $apiKey')) {
    throw const FormatException('此 API 规则需要私有凭据。');
  }
  return headers;
}

class AnimekoJsonSource implements MediaSourceAdapter {
  const AnimekoJsonSource(this.config, this.http);
  final ConfiguredSource config;
  final Dio http;

  AnimekoJsonRule get _rule =>
      AnimekoJsonRule.parse(ruleObject(jsonDecode(config.endpoint), 'API 配置'));
  @override
  String get id => config.id;
  @override
  String get name => config.name;
  @override
  int get priority => config.priority;

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final anime = request.anime;
    final episode = request.episode;
    if (anime == null || episode == null) return [];
    try {
      final rule = _rule;
      final names = [
        anime.title,
        anime.originalName,
        ...anime.aliases,
      ].where((entry) => entry.isNotEmpty && entry.length <= 240).toSet();
      if (names.isEmpty) return [];
      final normalized = names.map(EpisodeMatcher.normalizeTitle).toSet();
      final found = await rule._search.load(rule, http, {
        'keyword': names.first,
        'page': 1,
        'pageSize': 30,
      }, cancelToken);
      final matches =
          <
            ({
              int station,
              int? bangumi,
              String title,
              String? original,
              int? year,
              int? count,
            })
          >[];
      for (final row in animekoJsonPath(
        found,
        rule._search.data['selectItems'] as String,
      )) {
        if (row is! Map) continue;
        final provider = animekoId(
          row['bangumi_id'] ?? row['bangumiSubjectId'],
        );
        final title = animekoJsonField(
          row,
          rule._search.data['selectName'] as String,
        );
        final station = animekoId(
          animekoJsonField(row, rule._search.data['selectId'] as String),
        );
        if (title is! String ||
            station == null ||
            (provider != null
                ? provider != anime.id
                : !normalized.contains(EpisodeMatcher.normalizeTitle(title)))) {
          continue;
        }
        final original = row['title_original'];
        matches.add((
          station: station,
          bangumi: provider,
          title: title,
          original: original is String ? original : null,
          year: animekoId(row['release_year']),
          count: animekoId(row['total_episodes']),
        ));
      }
      if (matches.isEmpty) return [];
      matches.sort((a, b) => (b.bangumi ?? 0).compareTo(a.bangumi ?? 0));
      final match = matches.first;
      await Future<void>.delayed(rule.interval);
      final detail = await rule._subject.load(rule, http, {
        'id': match.station,
        'subjectId': match.station,
      }, cancelToken);
      final grouping = ruleObject(
        rule._subject.data['channelFormatGrouped'],
        '线路',
      );
      final fields = ruleObject(rule._subject.data['episodes'], '剧集');
      final types = <String, EpisodeKind>{};
      for (final row in (fields['typeMapping'] as String? ?? '').split('\n')) {
        final cells = row.split('=');
        if (cells.length == 2) {
          types[cells.first.trim()] = cells.last.trim() == 'MainStory'
              ? EpisodeKind.regular
              : EpisodeKind.special;
        }
      }
      final result = <SourceOffer>[];
      for (final group in animekoJsonPath(
        detail,
        grouping['selectChannels'] as String,
      ).take(12)) {
        final channel = animekoJsonField(
          group,
          grouping['selectChannelName'] as String,
        );
        if (channel is! String || channel.isEmpty || channel.length > 128) {
          continue;
        }
        for (final item in animekoJsonPath(
          group,
          fields['selectEpisodes'] as String,
        )) {
          if (item is! Map) continue;
          final stationId = animekoId(
            animekoJsonField(item, fields['selectId'] as String),
          );
          final order = num.tryParse(
            '${animekoJsonField(item, fields['selectSort'] as String)}',
          );
          final kind =
              types[animekoJsonField(item, fields['selectType'] as String)];
          final mappedEpisode = animekoId(
            item['bangumi_episode_id'] ?? item['bangumiEpisodeId'],
          );
          if (stationId == null ||
              order != episode.number ||
              kind != null && kind != episode.kind ||
              mappedEpisode != null && mappedEpisode != episode.id) {
            continue;
          }
          result.add(
            SourceOffer(
              sourceId: id,
              resourceId: animekoEncodeRecord([
                match.station,
                stationId,
                channel,
              ]),
              label: '$name · $channel',
              seriesTitle: match.title,
              subjectId: match.bangumi,
              episodeId: mappedEpisode,
              number: order,
              kind: kind,
              priority: priority,
              numberedWithinSubject: kind != null,
              seriesOriginalTitle: matches.length == 1 ? match.original : null,
              seriesYear: match.year,
              seriesEpisodeCount: match.count,
            ),
          );
          break;
        }
      }
      return result;
    } on FormatException {
      throw const SourceIssue(SourceState.failed, 'JSON API 规则或响应格式无效。');
    }
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    try {
      final values = animekoDecodeRecord(resourceId, 3);
      final subject = animekoId(values[0]);
      final episode = animekoId(values[1]);
      final channel = values[2];
      if (subject == null || episode == null || channel is! String) {
        throw const FormatException('剧集记录无效。');
      }
      final rule = _rule;
      await Future<void>.delayed(rule.interval);
      final data = await rule._play.load(rule, http, {
        'id': episode,
        'subjectId': subject,
        'episodeId': episode,
        'channel': channel,
      }, null);
      for (final row in animekoJsonPath(
        data,
        rule._play.data['selectCandidates'] as String,
      )) {
        if (animekoJsonField(
              row,
              rule._play.data['selectCandidateChannel'] as String,
            ) !=
            channel) {
          continue;
        }
        final raw = animekoJsonField(
          row,
          rule._play.data['selectVideoUrl'] as String,
        );
        if (raw is! String) continue;
        final media = animekoMedia(rule.origin, rule.origin, raw);
        if (media != null) return StreamAccess(media, restrictOrigin: true);
      }
      throw const SourceIssue(SourceState.failed, '此线路没有返回可播放的 MP4 或 HLS。');
    } on FormatException {
      throw const SourceIssue(SourceState.failed, 'JSON API 播放规则或响应格式无效。');
    }
  }

  @override
  Future<void> testConnection() async {
    try {
      final rule = _rule;
      await rule._search.load(rule, http, {
        'keyword': 'AniView',
        'page': 1,
        'pageSize': 10,
      }, null);
    } on FormatException {
      throw const SourceIssue(SourceState.failed, 'JSON API 响应格式无效。');
    }
  }
}
