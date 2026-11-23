import 'package:aniview/core/theme/app_theme.dart';
import 'package:aniview/features/sources/built_in_subscriptions.dart';
import 'package:aniview/media/sources/subscription_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = '''
{
  "schemaVersion": 2,
  "mediaSources": [
    {"id": "test", "factoryId": "json-api", "arguments": {
      "name": "示例目录", "searchUrl": "https://untrusted.example/", "script": "ignored"
    }}
  ],
  "exportedMediaSourceDataList": {"mediaSources": [{"id": "old"}]}
}
''';

void main() {
  test('extracts only member names and kinds from the v2 list', () {
    expect(SubscriptionCatalog.parse(_manifest), [
      (name: '示例目录', factory: 'json-api'),
    ]);
    expect(
      () => SubscriptionCatalog.parse(
        _manifest.replaceFirst('"schemaVersion": 2', '"schemaVersion": 3'),
      ),
      throwsFormatException,
    );
    expect(
      () => SubscriptionCatalog.parse(
        _manifest.replaceFirst('"name": "示例目录"', '"name": null'),
      ),
      throwsFormatException,
    );
  });

  test(
    'refresh requests only the built-in JSON endpoints without redirects',
    () async {
      final http = Dio();
      addTearDown(http.close);
      final requested = <Uri>[];
      http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requested.add(options.uri);
            expect(options.followRedirects, false);
            expect(options.validateStatus(302), false);
            expect(options.headers.keys, unorderedEquals(['Accept']));
            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody.fromString(_manifest, 200),
              ),
            );
          },
        ),
      );
      for (final subscription in BuiltInSubscription.values) {
        expect(
          await SubscriptionCatalog(http).refresh(subscription, CancelToken()),
          [(name: '示例目录', factory: 'json-api')],
        );
      }
      expect(requested.map((uri) => uri.toString()), [
        'https://sub.creamycake.org/v1/bt1.json',
        'https://sub.creamycake.org/v1/css1.json',
      ]);
    },
  );

  test('refuses an oversized manifest and cancels the response', () async {
    final http = Dio();
    addTearDown(http.close);
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<ResponseBody>(
            requestOptions: options,
            data: ResponseBody.fromBytes(List.filled(512 * 1024 + 1, 32), 200),
          ),
        ),
      ),
    );
    final cancellation = CancelToken();
    await expectLater(
      SubscriptionCatalog(http).refresh(BuiltInSubscription.css1, cancellation),
      throwsFormatException,
    );
    expect(cancellation.isCancelled, true);
  });

  testWidgets('both offline member lists open at phone width', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dim,
        home: const Scaffold(body: BuiltInSubscriptions()),
      ),
    );
    await tester.tap(find.textContaining('CreamyCake bt1.json'));
    await tester.pumpAndSettle();
    expect(find.text('2 个来源 · 内置清单'), findsOneWidget);
    expect(find.text('nyaa.land'), findsOneWidget);
    expect(find.text('AnimeGarden'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CreamyCake css1.json'));
    await tester.pumpAndSettle();
    expect(find.text('21 个来源 · 内置清单'), findsOneWidget);
    expect(find.text('稀饭动漫 Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
