import 'dart:convert';

import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/core/widgets/soft_controls.dart';
import 'package:aniview/features/sources/catalog_subscription_import.dart';
import 'package:aniview/media/sources/catalog_subscription.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

final _address = Uri.parse('https://library.example/subscription.json');

Map<String, String> _source(String format, {String? id}) => {
  'id': id ?? '$format-feed',
  'format': format,
  'name': '$format 目录',
  'endpoint': 'https://media.example/catalog/$format',
};

String _manifest(List<Map<String, Object?>> sources) =>
    jsonEncode({'schemaVersion': 1, 'sources': sources});

void main() {
  test('previews the bare CreamyCake address over HTTPS', () async {
    final http = Dio();
    addTearDown(http.close);
    final requests = <Uri>[];
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri);
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromString('''
                {"schemaVersion":2,"mediaSources":[
                  {"id":"web","factoryId":"web-selector","version":2,
                   "arguments":{"name":"网页目录"}},
                  {"id":"api","factoryId":"json-api","version":1,
                   "arguments":{"name":"API 目录"}}
                ]}
                ''', 200),
            ),
          );
        },
      ),
    );

    final first = await CatalogSubscription.read(
      http,
      '  sub.creamycake.org/v1/css1.json  ',
    );
    final explicit = await CatalogSubscription.read(
      http,
      'https://sub.creamycake.org/v1/css1.json',
    );
    expect(
      requests,
      List.filled(2, Uri.parse('https://sub.creamycake.org/v1/css1.json')),
    );
    expect(
      first.members.map((member) => member.sourceId),
      explicit.members.map((member) => member.sourceId),
    );
    expect(first.members.map((member) => member.formatLabel), [
      '缺少搜索规则。',
      '缺少搜索规则。',
    ]);
    expect(first.members.every((member) => !member.canImport), true);
  });

  test(
    'rejects invalid subscription addresses before making a request',
    () async {
      final http = Dio();
      addTearDown(http.close);
      http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              fail('Unexpected request: ${options.uri}'),
        ),
      );
      for (final input in [
        '',
        '/v1/css1.json',
        'https:/example.org/feed.json',
        'file:///test/example.json',
        'http://example.org/feed.json',
        'user@example.org/feed.json',
        'example.org/feed.json?token=hidden',
      ]) {
        await expectLater(
          CatalogSubscription.read(http, input),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('订阅地址'),
            ),
          ),
          reason: input,
        );
      }
    },
  );

  test('reads only supported manifest fields and makes stable local IDs', () {
    final body = _manifest([_source('json'), _source('rss'), _source('web')]);
    final first = CatalogSubscription.parse(body, _address).members;
    final again = CatalogSubscription.parse(
      body,
      Uri.parse('HTTPS://LIBRARY.EXAMPLE:443/subscription.json'),
    ).members;
    expect(first.map((entry) => entry.kind?.name), [
      'jsonFeed',
      'rssFeed',
      'webFeed',
    ]);
    expect(
      again.map((entry) => entry.sourceId),
      first.map((entry) => entry.sourceId),
    );
    expect(
      CatalogSubscription.parse(
        body,
        _address.replace(path: '/second.json'),
      ).members.first.sourceId,
      isNot(first.first.sourceId),
    );
  });

  test('rejects duplicate IDs, callbacks, magnets and unsafe endpoints', () {
    final rejected = [
      _manifest([_source('json'), _source('json')]),
      _manifest([_source('magnet')]),
      _manifest([
        {..._source('web'), 'script': 'fetch(...)'},
      ]),
      _manifest([
        {
          ..._source('json'),
          'headers': {'Authorization': 'injected'},
        },
      ]),
      _manifest([
        {..._source('json'), 'endpoint': 'http://media.example/catalog'},
      ]),
      _manifest([
        {
          ..._source('json'),
          'endpoint': 'https://media.example/catalog?t=secret',
        },
      ]),
      _manifest([
        {..._source('web'), 'endpoint': 'file:///tmp/feed'},
      ]),
      _manifest(List.generate(25, (i) => _source('rss', id: 'rss-$i'))),
      '{"schemaVersion":2,"mediaSources":{}}',
    ];
    for (final body in rejected) {
      expect(
        () => CatalogSubscription.parse(body, _address),
        throwsFormatException,
      );
    }
  });

  test(
    'imports reviewed entries once and preserves previous settings',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final vault = TestVault();
      final store = SourceStore(db, vault);
      final sub = CatalogSubscription.parse(
        _manifest([_source('json'), _source('rss')]),
        _address,
      );
      expect(await sub.importSelected(store, {'json-feed'}), (
        added: 1,
        skipped: 0,
      ));
      final sourceId = sub.members.first.sourceId;
      final original = (await store.byId(sourceId))!;
      expect(original.offlineAllowed, false);
      expect(original.enabled, true);
      expect(await store.byId(sub.members.last.sourceId), isNull);
      final edited = original.copyWith(
        name: '我的名称',
        enabled: false,
        priority: 8,
        endpoint: 'https://my.example/catalog',
      );
      await store.put(edited, secret: {'token': 'user-token'});

      final updated = CatalogSubscription.parse(
        _manifest([
          {
            ..._source('json'),
            'name': '更名后的来源',
            'endpoint': 'https://new.example/feed',
          },
          _source('rss'),
        ]),
        _address,
      );
      expect(await updated.importSelected(store, {'json-feed', 'rss-feed'}), (
        added: 1,
        skipped: 1,
      ));
      expect(await store.byId(sourceId), edited);
      expect(await store.credentials(sourceId), {'token': 'user-token'});
    },
  );

  testWidgets(
    'preview requests only the manifest and imports selected sources',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final store = SourceStore(db, TestVault());
      final http = Dio();
      addTearDown(db.close);
      addTearDown(http.close);
      final seen = <Uri>[];
      http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen.add(options.uri);
            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody.fromString(_manifest([_source('rss')]), 200),
              ),
            );
          },
        ),
      );
      await tester.runAsync(store.sources);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceStoreProvider.overrideWithValue(store),
            sourceRegistryProvider.overrideWithValue(
              MediaSourceRegistry(store, LocalLibrary(db), http),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dim,
            home: const Scaffold(body: CatalogSubscriptionImportButton()),
          ),
        ),
      );
      await tester.tap(find.text('导入订阅'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'library.example/subscription.json',
      );
      await tester.tap(find.text('预览订阅'));
      await tester.pumpAndSettle();
      expect(seen, [_address]);
      final add = find.widgetWithText(SoftButton, '导入所选片源');
      expect(tester.widget<SoftButton>(add).onPressed, isNull);
      await tester.tap(find.text('rss 目录'));
      await tester.pumpAndSettle();
      expect(tester.widget<SoftButton>(add).onPressed, isNotNull);
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(find.text('已添加 1 个片源'), findsOneWidget);
      final sources = (await tester.runAsync(store.sources))!;
      expect(sources.where((source) => source.kind == 'rssFeed').length, 1);
      expect(seen, [_address]);
      expect(tester.takeException(), isNull);
    },
  );
}
