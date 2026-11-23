import 'package:aniview/app/aniview_app.dart';
import 'package:aniview/app/providers.dart';
import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/media/sources/catalog_subscription.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/test_vault.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('public CSS subscription imports and plays the first episode', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        vaultProvider.overrideWithValue(TestVault()),
      ],
    );
    addTearDown(container.dispose);
    final registry = container.read(sourceRegistryProvider);
    final manifest = await CatalogSubscription.read(
      registry.http,
      'sub.creamycake.org/v1/css1.json',
    );
    final api = manifest.members.singleWhere(
      (member) => member.id == 'xifan-dongman-next',
    );
    expect(api.kind, SourceKind.animekoJson);
    debugPrint(
      'ANIVIEW_CSS_IMPORTABLE ${manifest.members.where((member) => member.canImport).length}/${manifest.members.length}',
    );
    expect(await manifest.importSelected(registry.store, {api.id}), (
      added: 1,
      skipped: 0,
    ));

    final repository = container.read(animeRepositoryProvider);
    final anime = (await repository.subject(9717)).value;
    expect(anime.title, '魔法少女小圆');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AniViewApp(),
      ),
    );
    await _wait(tester, find.text('AniView'));
    final router = GoRouter.of(tester.element(find.text('AniView')));
    final detail = router.push<void>('/anime/${anime.id}', extra: anime);
    await _wait(tester, find.text('番剧详情'));
    await tester.tap(find.text('立即播放'));

    final seek = find.byKey(const ValueKey('seek-bar'));
    await _wait(tester, seek, seconds: 40);
    final slider = tester.widget<Slider>(seek);
      expect(slider.max, greaterThan(120000));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Slider>(seek).value, greaterThan(0));
    final link = (await db.select(db.mediaLinks).get()).single;
    expect(link.sourceId, api.sourceId);
    final entry = (await db.select(db.mediaEntries).get()).single;
    expect(entry.subjectId, anime.id);
    expect(entry.episodeLabel, '第 1 集');
    debugPrint(
        'ANIVIEW_PUBLIC_PLAYBACK ${entry.title} ${entry.episodeLabel} duration_ms=${slider.max.round()}',
    );
    router.pop();
    await _wait(tester, find.text('番剧详情'));
    router.pop();
    await detail;
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !const bool.fromEnvironment('ANIVIEW_PUBLIC_SOURCE_QA'));
}

Future<void> _wait(
  WidgetTester tester,
  Finder target, {
  int seconds = 20,
}) async {
  final until = DateTime.now().add(Duration(seconds: seconds));
  while (target.evaluate().isEmpty && DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 180));
  }
  if (target.evaluate().isEmpty) {
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .nonNulls
        .take(15);
    debugPrint('ANIVIEW_VISIBLE ${labels.join(' | ')}');
  }
  expect(target, findsOneWidget);
}
