import 'dart:convert';
import 'dart:ui';

import 'package:aniview/features/home/home_screen.dart';
import 'package:aniview/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('sample real Flutter frames while scrolling the populated home', (
    tester,
  ) async {
    await app.main();
    final deadline = DateTime.now().add(const Duration(seconds: 32));
    while (find.byType(AnimeTile).evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      find.byType(AnimeTile),
      findsWidgets,
      reason: 'Live or cached Bangumi data is needed.',
    );
    await tester.pump(const Duration(seconds: 2));
    final home = find.byKey(const PageStorageKey('home-scroll'));
    final view = tester.getRect(home);
    final anchor = Offset(view.center.dx, view.top + view.height * .58);
    for (final direction in [-1.0, 1.0]) {
      await tester.timedDragFrom(
        anchor,
        Offset(0, direction * 230),
        const Duration(milliseconds: 450),
        frequency: 90,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    final timings = <FrameTiming>[];
    final callback = timings.addAll;
    SchedulerBinding.instance.addTimingsCallback(callback);
    try {
      for (var i = 0; i < 12; i++) {
        final direction = i.isEven ? -1.0 : 1.0;
        await tester.timedDragFrom(
          anchor,
          Offset(0, direction * 260),
          const Duration(milliseconds: 500),
          frequency: 90,
        );
        await tester.pump(const Duration(milliseconds: 210));
      }
      await tester.pump(const Duration(seconds: 2));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(callback);
    }
    expect(timings.length, greaterThan(30));
    final report = {
      'frame_count': timings.length,
      'logical_width_dp': view.width,
      'build_ms': _summarize(timings.map((frame) => frame.buildDuration)),
      'raster_ms': _summarize(timings.map((frame) => frame.rasterDuration)),
      'total_span_ms': _summarize(timings.map((frame) => frame.totalSpan)),
    };
    binding.reportData = report;
    debugPrint('ANIVIEW_FRAME_TIMINGS ${jsonEncode(report)}');
  });
}

Map<String, Object> _summarize(Iterable<Duration> durations) {
  final values =
      durations.map((duration) => duration.inMicroseconds / 1000).toList()
        ..sort();
  double p(double fraction) => values[(values.length * fraction).ceil() - 1];
  return {
    'mean': values.reduce((a, b) => a + b) / values.length,
    'p50': p(.5),
    'p90': p(.9),
    'p99': p(.99),
    'over_16_67_ms': values.where((ms) => ms > 16.67).length,
  };
}
