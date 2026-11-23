import 'package:dio/dio.dart';

import '../../core/database/app_database.dart';
import '../../core/database/local_library.dart';
import '../../features/anime/anime.dart';
import '../media.dart';
import 'episode_matcher.dart';
import 'source_models.dart';
import 'source_store.dart';

Dio createMediaHttp() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 7),
    sendTimeout: const Duration(seconds: 5),
    followRedirects: false,
  ),
);

Uri serverEndpoint(String input) {
  final uri = parsePlaybackUrl(input);
  if (uri.hasQuery || input.contains('#')) {
    throw const FormatException('服务器地址请填写服务根路径，可以包含反向代理前缀。');
  }
  final host = uri.host.toLowerCase();
  final local =
      host == 'localhost' ||
      host == '::1' ||
      host.endsWith('.local') ||
      RegExp(r'^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)')
              .hasMatch(host) &&
          RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);
  if (!uri.isScheme('https') && !local) {
    throw const FormatException('公网服务器请使用 HTTPS，局域网可使用 HTTP。');
  }
  return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
}

Map<String, String> parseMediaHeaders(String input) {
  final headers = <String, String>{};
  const allowed = {
    'authorization',
    'cookie',
    'x-api-key',
    'user-agent',
    'referer',
    'accept',
  };
  for (final line in input.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final colon = line.indexOf(':');
    if (colon <= 0) throw const FormatException('请求头请每行填写“名称: 值”。');
    final name = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    if (!allowed.contains(name) ||
        headers.containsKey(name) ||
        value.isEmpty ||
        value.length > 4096 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const FormatException('请求头不受支持、重复或格式有误。');
    }
    headers[name] = value;
  }
  return headers;
}

SourceIssue sourceHttpFailure(DioException error) {
  return switch (error.response?.statusCode) {
    401 => const SourceIssue(SourceState.login, '请重新登录此片源。'),
    403 => const SourceIssue(SourceState.forbidden, '该账号没有访问此资源的权限。'),
    404 => const SourceIssue(SourceState.failed, '服务器没有找到该资源。'),
    429 => const SourceIssue(SourceState.suspect, '服务器请求频率受限，请稍后重试。'),
    final int code when code >= 300 && code < 400 => const SourceIssue(
      SourceState.failed,
      '片源发生重定向，请配置实际地址。',
    ),
    _ => const SourceIssue(SourceState.suspect, '连接失败或超时，请检查网络和服务器。'),
  };
}

class LocalSource implements MediaSourceAdapter {
  const LocalSource(this.config, this.library);
  final ConfiguredSource config;
  final LocalLibrary library;
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
  }) async => [
    for (final media in await library.candidates(request))
      if (media.kind == MediaKind.document && media.uri.scheme != 'aniview')
        _savedOffer(config, media),
  ];

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    final media = await library.mediaById(resourceId);
    if (media == null || media.kind != MediaKind.document) {
      throw const SourceIssue(SourceState.failed, '本地文件记录已找不到。');
    }
    return StreamAccess(media.uri);
  }

  @override
  Future<void> testConnection() async {}
}

class DirectUrlSource implements MediaSourceAdapter {
  const DirectUrlSource(this.config, this.store, this.library);
  final ConfiguredSource config;
  final SourceStore store;
  final LocalLibrary library;
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
    if (id == 'legacy-direct') {
      final media = await library.candidates(request);
      return [
        for (final entry in media)
          if (entry.kind == MediaKind.direct && entry.uri.scheme != 'aniview')
            _savedOffer(config, entry),
      ];
    }
    if (request.anime != null) {
      if (config.subjectId == null && config.subjectTitle.isEmpty) return [];
      if (config.subjectId != null && config.subjectId != request.anime!.id) {
        return [];
      }
    }
    if (request.episode != null &&
        config.episodeId != null &&
        request.episode!.id != config.episodeId) {
      return [];
    }
    return [
      SourceOffer(
        sourceId: id,
        resourceId: id,
        label: name,
        subjectId: config.subjectId,
        episodeId: config.episodeId,
        seriesTitle: config.subjectTitle,
        priority: priority,
      ),
    ];
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    if (id == 'legacy-direct') {
      final media = await library.mediaById(resourceId);
      if (media != null) return StreamAccess(media.uri);
    } else {
      final saved = await store.credentials(id);
      if (saved != null && saved['url'] is String) {
        return StreamAccess(
          parsePlaybackUrl(saved['url'] as String),
          headers: Map<String, String>.from(
            saved['headers'] as Map? ?? const {},
          ),
        );
      }
    }
    throw const SourceIssue(SourceState.failed, '播放地址已被删除。');
  }

  @override
  Future<void> testConnection() async {}
}

SourceOffer _savedOffer(ConfiguredSource config, MediaCandidate media) =>
    SourceOffer(
      sourceId: config.id,
      resourceId: media.id,
      label: media.sourceName,
      subjectId: media.subjectId,
      episodeId: media.episodeId,
      priority: config.priority,
      saved: media,
    );

class JellyfinSource implements MediaSourceAdapter {
  const JellyfinSource(this.config, this.store, this.http);

  final ConfiguredSource config;
  final SourceStore store;
  final Dio http;
  bool get isEmby => false;
  @override
  String get id => config.id;
  @override
  String get name => config.name;
  @override
  int get priority => config.priority;

  Uri _uri(String path) => Uri.parse('${config.endpoint}$path');
  static String _id(String input) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(input)) {
      throw const SourceIssue(SourceState.failed, '服务器返回了不支持的资源 ID。');
    }
    return input;
  }

  Map<String, String> _headers([String? token]) => {
    'Authorization': isEmby
        ? 'Emby ${token == null ? '' : 'UserId="${_id(config.userId)}", '}'
              'Client="Android", Device="AniView", DeviceId="$id", Version="0.2.5"'
        : 'MediaBrowser Client="AniView", Device="Android", '
              'DeviceId="$id", Version="0.2.5"${token == null ? '' : ', Token="$token"'}',
    if (isEmby && token != null) 'X-Emby-Token': token,
    'Accept': 'application/json',
  };

  Future<Map<String, String>> _auth() async {
    final token = (await store.credentials(id))?['token'];
    if (token is! String ||
        !RegExp(r'^[a-zA-Z0-9_.~+/=-]{1,512}$').hasMatch(token)) {
      throw const SourceIssue(SourceState.login, '请在片源管理里登录。');
    }
    return _headers(token);
  }

  Future<({String userId, String token})> login(
    String username,
    String password,
  ) async {
    final result = await _request(
      '/Users/AuthenticateByName',
      _headers(),
      body: {'Username': username, 'Pw': password},
    );
    final user = result['User'];
    final token = result['AccessToken'];
    if (user is! Map ||
        user['Id'] is! String ||
        token is! String ||
        token.isEmpty) {
      throw const SourceIssue(SourceState.login, '登录响应缺少账号或访问凭据。');
    }
    return (userId: _id(user['Id'] as String), token: token);
  }

  @override
  Future<void> testConnection() async {
    final headers = await _auth();
    await _request('/Users/${_id(config.userId)}', headers);
  }

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, String> headers, {
    Map<String, Object>? body,
    Map<String, Object>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await http.requestUri<Object?>(
        _uri(path).replace(
          queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
        ),
        data: body,
        cancelToken: cancelToken,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: headers,
        ),
      );
      if (response.data case final Map<String, dynamic> result) return result;
      throw const SourceIssue(SourceState.failed, '服务器返回的媒体资料格式不受支持。');
    } on DioException catch (error) {
      throw sourceHttpFailure(error);
    }
  }

  @override
  Future<List<SourceOffer>> search(
    MediaSearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final anime = request.anime;
    final episode = request.episode;
    if (anime == null) return [];
    final auth = await _auth();
    final names = [
      anime.title,
      anime.originalName,
      ...anime.aliases,
    ].where((value) => value.trim().isNotEmpty).toSet();
    final offers = <String, SourceOffer>{};
    for (final term in names.take(3)) {
      final result = await _request(
        '/Items',
        auth,
        cancelToken: cancelToken,
        query: {
          'UserId': config.userId,
          'Recursive': true,
          'SearchTerm': term,
          'IncludeItemTypes': episode == null ? 'Movie' : 'Series',
          'Fields': 'OriginalTitle,ProviderIds',
          'Limit': 6,
        },
      );
      final candidates = _items(result);
      for (final series in candidates.take(3)) {
        final guid = series['Id'];
        if (guid is! String) continue;
        final seriesTitle = _name(series);
        final aliases = [
          seriesTitle,
          series['OriginalTitle'],
        ].whereType<String>();
        final identified = _bgmId(series);
        final exact = aliases.any(
          (alias) => names
              .map(EpisodeMatcher.normalizeTitle)
              .contains(EpisodeMatcher.normalizeTitle(alias)),
        );
        if (!exact && identified != anime.id) continue;
        if (episode == null) {
          offers[guid] = SourceOffer(
            sourceId: id,
            resourceId: guid,
            label: '$name · $seriesTitle',
            subjectId: identified,
            seriesTitle: seriesTitle,
            priority: priority,
          );
          continue;
        }
        final season = names.map(EpisodeMatcher.seasonHint).nonNulls.toSet();
        final episodes = await _request(
          '/Shows/${_id(guid)}/Episodes',
          auth,
          cancelToken: cancelToken,
          query: {
            'UserId': config.userId,
            'Limit': 120,
            'Fields': 'MediaStreams,ProviderIds',
            if (episode.kind == EpisodeKind.special)
              'Season': 0
            else if (season.length == 1)
              'Season': season.single,
          },
        );
        for (final item in _items(episodes)) {
          final resource = item['Id'];
          final number = item['IndexNumber'];
          final parent = item['ParentIndexNumber'];
          if (resource is! String ||
              number is! num ||
              number != episode.number) {
            continue;
          }
          final streams = (item['MediaStreams'] as List? ?? const [])
              .whereType<Map>();
          final width = streams
              .where((stream) => stream['Type'] == 'Video')
              .map((stream) => stream['Width'])
              .whereType<int>()
              .firstOrNull;
          List<String> languages(String type) => streams
              .where((stream) => stream['Type'] == type)
              .map((stream) => stream['Language'])
              .whereType<String>()
              .toList();
          offers[resource] = SourceOffer(
            sourceId: id,
            resourceId: resource,
            label: '$name · $seriesTitle ${_name(item)}',
            subjectId: identified,
            episodeId: _bgmId(item),
            seriesTitle: seriesTitle,
            number: number,
            season: parent is int && parent > 0 ? parent : null,
            kind: parent == 0
                ? EpisodeKind.special
                : parent is int
                ? EpisodeKind.regular
                : null,
            priority: priority,
            width: width,
            audioLanguages: languages('Audio'),
            subtitleLanguages: languages('Subtitle'),
          );
        }
      }
      if (offers.isNotEmpty) break;
    }
    return offers.values.toList();
  }

  static Iterable<Map<String, dynamic>> _items(Map<String, dynamic> result) =>
      (result['Items'] as List? ?? const []).whereType<Map<String, dynamic>>();
  static String _name(Map<String, dynamic> row) =>
      row['Name'] is String ? row['Name'] as String : '';
  static int? _bgmId(Map<String, dynamic> row) {
    final providers = row['ProviderIds'];
    if (providers is! Map) return null;
    return int.tryParse('${providers['Bangumi'] ?? providers['Bgm'] ?? ''}');
  }

  @override
  Future<StreamAccess> resolve(String resourceId) async {
    final auth = await _auth();
    final resource = _id(resourceId);
    final info = await _request(
      '/Items/$resource/PlaybackInfo',
      auth,
      query: {'UserId': config.userId},
    );
    final sources = (info['MediaSources'] as List? ?? const [])
        .whereType<Map>();
    final stream = sources
        .where(
          (source) =>
              source['SupportsDirectPlay'] == true &&
              source['IsRemote'] != true,
        )
        .firstOrNull;
    if (stream == null) {
      throw const SourceIssue(SourceState.failed, '该项没有可直放的服务端原始视频。');
    }
    final streamId = stream['Id'];
    return StreamAccess(
      _uri('/Videos/$resource/stream').replace(
        queryParameters: {
          'Static': 'true',
          if (streamId is String) 'MediaSourceId': _id(streamId),
        },
      ),
      headers: {...auth}..remove('Accept'),
    );
  }
}

class EmbySource extends JellyfinSource {
  const EmbySource(super.config, super.store, super.http);
  @override
  bool get isEmby => true;
}
