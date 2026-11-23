import 'dart:convert';

import 'package:dio/dio.dart';

typedef SubscriptionMember = ({String name, String factory});

enum BuiltInSubscription {
  bt1('BT 索引', [
    (name: 'nyaa.land', factory: 'rss'),
    (name: 'AnimeGarden', factory: 'rss'),
  ]),
  css1('Web / API', [
    (name: '稀饭动漫', factory: 'web-selector'),
    (name: 'girigiri愛動漫', factory: 'web-selector'),
    (name: '稀饭动漫 Next', factory: 'json-api'),
    (name: '2k动漫', factory: 'web-selector'),
    (name: '嘀嗒影视', factory: 'web-selector'),
    (name: '叽哔动漫', factory: 'web-selector'),
    (name: 'E-ACG', factory: 'web-selector'),
    (name: '森之屋动漫', factory: 'web-selector'),
    (name: '风车影视', factory: 'web-selector'),
    (name: '去看吧', factory: 'web-selector'),
    (name: 'Anime7', factory: 'web-selector'),
    (name: '海星动漫', factory: 'web-selector'),
    (name: '樱花动漫', factory: 'web-selector'),
    (name: '嘀哩嘀哩', factory: 'web-selector'),
    (name: '新优酷', factory: 'web-selector'),
    (name: '番茄动漫', factory: 'web-selector'),
    (name: 'hanime1_1080p', factory: 'web-selector'),
    (name: 'hanime1_720p', factory: 'web-selector'),
    (name: 'wedm', factory: 'web-selector'),
    (name: '影视森林', factory: 'web-selector'),
    (name: '热播之家', factory: 'web-selector'),
  ]);

  const BuiltInSubscription(this.category, this.snapshot);

  final String category;
  // Public directory metadata verified on 2026-11-19.
  final List<SubscriptionMember> snapshot;

  String get fileName => '$name.json';
  Uri get uri => Uri.https('sub.creamycake.org', '/v1/$fileName');
}

class SubscriptionCatalog {
  const SubscriptionCatalog(this._http);

  final Dio _http;
  static const _maxBytes = 512 * 1024;

  Future<List<SubscriptionMember>> refresh(
    BuiltInSubscription subscription,
    CancelToken cancellation,
  ) => _read(subscription, cancellation).timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      cancellation.cancel();
      throw const FormatException('订阅读取超时。');
    },
  );

  Future<List<SubscriptionMember>> _read(
    BuiltInSubscription subscription,
    CancelToken cancellation,
  ) async {
    final response = await _http.getUri<ResponseBody>(
      subscription.uri,
      cancelToken: cancellation,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status == 200,
        headers: {'Accept': 'application/json'},
      ),
    );
    final body = response.data;
    if (body == null) throw const FormatException('订阅清单为空。');
    final bytes = <int>[];
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > _maxBytes) {
        cancellation.cancel();
        throw const FormatException('订阅清单超出大小限制。');
      }
      bytes.addAll(chunk);
    }
    return parse(utf8.decode(bytes));
  }

  static List<SubscriptionMember> parse(String json) {
    final data = jsonDecode(json);
    if (data is! Map<String, dynamic> ||
        data['schemaVersion'] != 2 ||
        data['mediaSources'] is! List) {
      throw const FormatException('不支持的订阅清单格式。');
    }
    final ids = <String>{};
    final members = <SubscriptionMember>[];
    for (final item in data['mediaSources'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('订阅条目格式有误。');
      }
      final id = item['id'];
      final factory = item['factoryId'];
      final arguments = item['arguments'];
      final name = arguments is Map<String, dynamic> ? arguments['name'] : null;
      if (id is! String ||
          id.trim().isEmpty ||
          factory is! String ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 120 ||
          !ids.add(id)) {
        throw const FormatException('订阅条目名称或标识有误。');
      }
      members.add((name: name.trim(), factory: factory));
    }
    return List.unmodifiable(members);
  }
}
