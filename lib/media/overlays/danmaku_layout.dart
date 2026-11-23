import 'media_overlays.dart';

class PlacedDanmaku {
  const PlacedDanmaku({
    required this.index,
    required this.item,
    required this.lane,
    required this.left,
    required this.top,
    required this.width,
  });

  final int index;
  final DanmakuItem item;
  final int lane;
  final double left;
  final double top;
  final double width;
}

class DanmakuLayoutEngine {
  static const double gapPx = 24.0;

  DanmakuTrack? _lastTrack;
  int? _lastMs;
  double? _lastWidth;
  double? _lastFontSize;
  int? _lastLifeMs;
  double? _lastAreaRatio;

  final Map<int, ({int lane, double width, int start, DanmakuMode mode})>
  _active = {};

  void reset() {
    _active.clear();
  }

  List<PlacedDanmaku> layout({
    required DanmakuTrack track,
    required int ms,
    required int lifeMs,
    required int limit,
    required List<String> blocked,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
    required double Function(DanmakuItem item) measureWidth,
    double areaRatio = 0.5,
    bool showScroll = true,
    bool showTop = true,
    bool showBottom = true,
  }) {
    if (viewportWidth <= 0 || viewportHeight <= 0 || lifeMs <= 0) {
      return const [];
    }
    final clampedArea = areaRatio.clamp(0.2, 1.0);

    final shouldReset =
        !identical(_lastTrack, track) ||
        _lastMs == null ||
        ms < _lastMs! - 500 ||
        ms > _lastMs! + 3000 ||
        _lastWidth == null ||
        (_lastWidth! - viewportWidth).abs() > 24 ||
        _lastFontSize == null ||
        (_lastFontSize! - fontSize).abs() > 0.5 ||
        _lastLifeMs != lifeMs ||
        _lastAreaRatio == null ||
        (_lastAreaRatio! - clampedArea).abs() > 0.02;

    if (shouldReset) {
      _active.clear();
    }

    _lastTrack = track;
    _lastMs = ms;
    _lastWidth = viewportWidth;
    _lastFontSize = fontSize;
    _lastLifeMs = lifeMs;
    _lastAreaRatio = clampedArea;

    _active.removeWhere(
      (_, entry) => entry.start + lifeMs <= ms || entry.start > ms,
    );

    final lineHeight = fontSize * 1.42;
    final scrollLanes = (viewportHeight * clampedArea / lineHeight).floor().clamp(1, 16);
    final fixedLanes = (viewportHeight * (clampedArea * 0.65).clamp(0.2, 0.7) / lineHeight)
        .floor()
        .clamp(1, 8);
    final placed = <PlacedDanmaku>[];

    for (final (index, item) in track.visibleIndexed(
      ms,
      lifeMs,
      limit,
      blocked,
      showScroll: showScroll,
      showTop: showTop,
      showBottom: showBottom,
    )) {
      final lanes = item.mode == DanmakuMode.scroll ? scrollLanes : fixedLanes;
      var assignment = _active[index];
      if (assignment != null && assignment.lane >= lanes) {
        assignment = null;
      }

      if (assignment == null) {
        final width = measureWidth(item);
        final lane = _findFreeLane(
          item: item,
          width: width,
          lanes: lanes,
          lifeMs: lifeMs,
          viewportWidth: viewportWidth,
        );
        if (lane == null) continue;
        assignment = (
          lane: lane,
          width: width,
          start: item.start,
          mode: item.mode,
        );
        _active[index] = assignment;
      }

      final age = ((ms - item.start) / lifeMs).clamp(0.0, 1.0);
      final left = item.mode == DanmakuMode.scroll
          ? viewportWidth - (viewportWidth + assignment.width) * age
          : (viewportWidth - assignment.width) / 2;
      final top = item.mode == DanmakuMode.bottom
          ? (viewportHeight - (assignment.lane + 1) * lineHeight - 16.0).clamp(
              0.0,
              (viewportHeight - lineHeight).clamp(0.0, viewportHeight),
            )
          : (assignment.lane * lineHeight + 8.0);

      placed.add(
        PlacedDanmaku(
          index: index,
          item: item,
          lane: assignment.lane,
          left: left,
          top: top,
          width: assignment.width,
        ),
      );
    }

    return placed;
  }

  int? _findFreeLane({
    required DanmakuItem item,
    required double width,
    required int lanes,
    required int lifeMs,
    required double viewportWidth,
  }) {
    final vB = (viewportWidth + width) / lifeMs;
    for (var lane = 0; lane < lanes; lane++) {
      var conflict = false;
      for (final existing in _active.values) {
        if (existing.mode != item.mode || existing.lane != lane) continue;
        if (item.mode != DanmakuMode.scroll) {
          if (item.start < existing.start + lifeMs &&
              existing.start < item.start + lifeMs) {
            conflict = true;
            break;
          }
        } else {
          if (item.start >= existing.start + lifeMs) continue;
          if (item.start < existing.start) {
            // Check symmetry if an out-of-order item was inserted.
            if (!_scrollPairSafe(
              firstStart: item.start,
              firstWidth: width,
              secondStart: existing.start,
              secondSpeed: (viewportWidth + existing.width) / lifeMs,
              lifeMs: lifeMs,
              viewportWidth: viewportWidth,
            )) {
              conflict = true;
              break;
            }
          } else {
            if (!_scrollPairSafe(
              firstStart: existing.start,
              firstWidth: existing.width,
              secondStart: item.start,
              secondSpeed: vB,
              lifeMs: lifeMs,
              viewportWidth: viewportWidth,
            )) {
              conflict = true;
              break;
            }
          }
        }
      }
      if (!conflict) return lane;
    }
    return null;
  }

  bool _scrollPairSafe({
    required int firstStart,
    required double firstWidth,
    required int secondStart,
    required double secondSpeed,
    required int lifeMs,
    required double viewportWidth,
  }) {
    final firstSpeed = (viewportWidth + firstWidth) / lifeMs;
    final clearedEmission =
        firstSpeed * (secondStart - firstStart) >= firstWidth + gapPx;
    if (!clearedEmission) return false;
    final exitAt = firstStart + lifeMs;
    final secondLeftAtExit = viewportWidth - secondSpeed * (exitAt - secondStart);
    return secondLeftAtExit >= gapPx;
  }
}
