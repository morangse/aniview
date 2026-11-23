import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show InsertMode;

import '../../core/database/app_database.dart';
import 'animeko_json_source.dart';
import 'animeko_rss_source.dart';
import 'animeko_web_source.dart';
import 'catalog_entries.dart';
import 'catalog_source.dart';
import 'source_models.dart';
import 'source_store.dart';

class CatalogSubscriptionMember {
  const CatalogSubscriptionMember._({
    required this.id,
    required this.name,
    required this.kind,
    required this.endpoint,
    required this.sourceId,
    this.rule,
    this.unavailableLabel,
  });

  final String id;
  final String name;
  final SourceKind? kind;
  final Uri? endpoint;
  final String sourceId;
  final String? rule;
  final String? unavailableLabel;

  bool get canImport => kind != null;

  String get formatLabel =>
      unavailableLabel ??
      switch (kind) {
        SourceKind.jsonFeed => 'JSON',
        SourceKind.rssFeed => 'RSS',
        SourceKind.webFeed => 'Web',
        SourceKind.animekoRss => 'Animeko RSS · MP4/HLS 附件',
        SourceKind.animekoWeb => 'Animeko 网页',
        SourceKind.animekoJson => 'Animeko JSON API',
        _ => throw StateError('Unexpected catalog subscription source kind'),
      };
}

typedef CatalogImportResult = ({int added, int skipped});

class CatalogSubscription {
  const CatalogSubscription._(this.members);

  final List<CatalogSubscriptionMember> members;

  static const _maxMembers = 24;
  static const _manifestKeys = {'schemaVersion', 'sources'};
  static const _sourceKeys = {'id', 'name', 'format', 'endpoint'};
  static final _nameControls = RegExp(
    r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]',
  );
  static final _absoluteAddress = RegExp(
    r'^[a-z][a-z0-9+.-]*://',
    caseSensitive: false,
  );

  static Future<CatalogSubscription> read(
    Dio http,
    String address, {
    CancelToken? cancelToken,
  }) async {
    final uri = _readAddress(address);
    final body = await readCatalogText(http, uri, cancelToken: cancelToken);
    return parse(body, uri);
  }

  static Uri _readAddress(String address) {
    final value = address.trim();
    final hasScheme = _absoluteAddress.hasMatch(value);
    try {
      final uri = parseCatalogEndpoint(hasScheme ? value : 'https://$value');
      if (hasScheme ||
          uri.host.contains('.') ||
          uri.host.contains(':') ||
          uri.host == 'localhost') {
        return uri;
      }
    } on FormatException {
      // Keep subscription-input errors separate from playback address errors.
    }
    throw const FormatException('请输入有效的订阅地址，例如 example.org/feed.json。');
  }

  static CatalogSubscription parse(String body, Uri manifestUri) {
    final uri = parseCatalogEndpoint(manifestUri.toString());
    final payload = jsonDecode(body);
    if (payload is Map<String, dynamic> && payload['schemaVersion'] == 2) {
      return _parseAnimeko(payload['mediaSources'], uri);
    }
    if (payload is! Map<String, dynamic> ||
        payload.keys.any((key) => !_manifestKeys.contains(key)) ||
        payload['schemaVersion'] != 1 ||
        payload['sources'] is! List) {
      throw const FormatException('请选择 AniView v1 或 Animeko v2 片源订阅。');
    }
    final sources = payload['sources'] as List;
    if (sources.length > _maxMembers) {
      throw const FormatException('每份订阅最多支持 24 个片源。');
    }
    final seen = <String>{};
    return CatalogSubscription._(
      List.unmodifiable(
        sources.map((entry) {
          final member = _parseMember(entry, uri);
          if (!seen.add(member.id)) {
            throw const FormatException('订阅里有重复的片源标识。');
          }
          return member;
        }),
      ),
    );
  }

  static CatalogSubscriptionMember _parseMember(Object? item, Uri manifest) {
    if (item is! Map<String, dynamic> ||
        item.keys.any((key) => !_sourceKeys.contains(key))) {
      throw const FormatException('订阅片源含有不支持的字段。');
    }
    final id = item['id'];
    final name = item['name'];
    final address = item['endpoint'];
    final kind = switch (item['format']) {
      'json' => SourceKind.jsonFeed,
      'rss' => SourceKind.rssFeed,
      'web' => SourceKind.webFeed,
      _ => throw const FormatException('订阅只支持 JSON、RSS 和 Web 片源。'),
    };
    if (id is! String ||
        !isCatalogId(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 120 ||
        _nameControls.hasMatch(name) ||
        address is! String) {
      throw const FormatException('订阅片源的标识、名称或地址无效。');
    }
    return CatalogSubscriptionMember._(
      id: id,
      name: name.trim(),
      kind: kind,
      endpoint: parseCatalogEndpoint(address),
      sourceId: _localId(manifest, id),
    );
  }

  static String _localId(Uri manifest, String memberId) =>
      'catalog-${sha256.convert(utf8.encode(jsonEncode([manifest.toString(), memberId])))}';

  static CatalogSubscription _parseAnimeko(Object? sources, Uri manifest) {
    if (sources is! List || sources.length > 64) {
      throw const FormatException('Animeko 订阅清单无效或超过 64 个片源。');
    }
    final seen = <String>{};
    final members = <CatalogSubscriptionMember>[];
    for (final item in sources) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Animeko 订阅条目必须为对象。');
      }
      final id = item['id'];
      final factory = item['factoryId'];
      final args = item['arguments'];
      final name = args is Map<String, dynamic> ? args['name'] : null;
      if (id is! String ||
          !isCatalogId(id) ||
          !seen.add(id) ||
          factory is! String ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 120 ||
          _nameControls.hasMatch(name)) {
        throw const FormatException('Animeko 条目名称或标识无效。');
      }
      final config = (args as Map<String, dynamic>)['searchConfig'];
      final rule = _animekoRule(factory, item['version'], config);
      members.add(
        CatalogSubscriptionMember._(
          id: id,
          name: name.trim(),
          kind: rule.kind,
          sourceId: _localId(manifest, id),
          endpoint: rule.origin,
          rule: rule.storage,
          unavailableLabel: rule.issue,
        ),
      );
    }
    return CatalogSubscription._(List.unmodifiable(members));
  }

  static ({SourceKind? kind, Uri? origin, String? storage, String? issue})
  _animekoRule(String factory, Object? version, Object? config) {
    try {
      if (config is! Map<String, dynamic>) {
        throw const FormatException('缺少搜索规则。');
      }
      switch ((factory, version)) {
        case ('rss', 1):
          final url = config['searchUrl'];
          if (url is! String) {
            throw const FormatException('缺少 RSS 搜索地址。');
          }
          final rule = AnimekoRssAddress.parse(url);
          return (
            kind: SourceKind.animekoRss,
            origin: rule.origin,
            storage: rule.template,
            issue: null,
          );
        case ('web-selector', 2):
          final rule = AnimekoWebRule.parse(config);
          return (
            kind: SourceKind.animekoWeb,
            origin: rule.origin,
            storage: rule.storage,
            issue: null,
          );
        case ('json-api', 1):
          final rule = AnimekoJsonRule.parse(config);
          return (
            kind: SourceKind.animekoJson,
            origin: rule.origin,
            storage: rule.storage,
            issue: null,
          );
        default:
          throw const FormatException('不支持此规则类型或版本。');
      }
    } on FormatException catch (error) {
      return (kind: null, origin: null, storage: null, issue: error.message);
    }
  }

  Future<CatalogImportResult> importSelected(
    SourceStore store,
    Set<String> selectedIds,
  ) {
    final selected = [
      for (final member in members)
        if (member.canImport && selectedIds.contains(member.id)) member,
    ];
    return store.db.transaction(() async {
      var added = 0;
      final table = store.db.into(store.db.configuredSources);
      for (final member in selected) {
        final receipt = await table.insertReturningOrNull(
          ConfiguredSource(
            id: member.sourceId,
            name: member.name,
            kind: member.kind!.name,
            endpoint: member.rule ?? member.endpoint.toString(),
            userId: '',
            enabled: true,
            priority: 0,
            offlineAllowed: false,
            subjectTitle: '',
          ),
          mode: InsertMode.insertOrIgnore,
        );
        if (receipt != null) added++;
      }
      return (added: added, skipped: selected.length - added);
    });
  }
}
