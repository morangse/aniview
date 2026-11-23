import 'dart:async';
import 'dart:convert';

import '../../media/sources/source_store.dart';
import '../anime/anime.dart';

class SkipMarkers {
  const SkipMarkers({this.introEndMs, this.outroDurationMs});

  static const _unset = Object();

  final int? introEndMs;
  final int? outroDurationMs;

  bool get isEmpty => introEndMs == null && outroDurationMs == null;

  bool inIntro(Duration position, Duration duration) {
    final end = introEndMs;
    if (end == null || end <= 0) return false;
    final dur = duration.inMilliseconds;
    return dur > end && position.inMilliseconds < end;
  }

  bool inOutro(Duration position, Duration duration) {
    final outro = outroDurationMs;
    if (outro == null || outro <= 0) return false;
    final dur = duration.inMilliseconds;
    if (dur <= outro) return false;
    final pos = position.inMilliseconds;
    return pos >= dur - outro && pos < dur - 1000;
  }

  SkipMarkers copyWith({
    Object? introEndMs = _unset,
    Object? outroDurationMs = _unset,
  }) => SkipMarkers(
    introEndMs: identical(introEndMs, _unset)
        ? this.introEndMs
        : introEndMs as int?,
    outroDurationMs: identical(outroDurationMs, _unset)
        ? this.outroDurationMs
        : outroDurationMs as int?,
  );

  factory SkipMarkers.fromJson(Map<String, dynamic> json) {
    final intro = (json['introEndMs'] as num?)?.toInt();
    final outro = (json['outroDurationMs'] as num?)?.toInt();
    return SkipMarkers(
      introEndMs: intro != null && intro > 0 ? intro : null,
      outroDurationMs: outro != null && outro > 0 ? outro : null,
    );
  }

  Map<String, Object?> toJson() => {
    'introEndMs': introEndMs,
    'outroDurationMs': outroDurationMs,
  };
}

class SkipMarkersStore {
  const SkipMarkersStore(this.store);

  final SourceStore store;

  static String keyFor(int subjectId) => 'skip.markers.$subjectId';

  Future<SkipMarkers> load(int subjectId) async {
    final raw = await store.preference(keyFor(subjectId));
    if (raw == null || raw.isEmpty) return const SkipMarkers();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SkipMarkers.fromJson(decoded);
      }
    } on FormatException {
      // Ignore malformed JSON and treat as empty markers.
    }
    return const SkipMarkers();
  }

  Future<void> save(int subjectId, SkipMarkers markers) =>
      store.setPreference(keyFor(subjectId), jsonEncode(markers.toJson()));
}

class AutoNextCountdown {
  Timer? _timer;
  Episode? episode;
  int seconds = 0;

  bool get active => episode != null;

  void start({
    required Episode nextEpisode,
    int initialSeconds = 5,
    required void Function() onTick,
    required void Function(Episode episode) onComplete,
  }) {
    _timer?.cancel();
    episode = nextEpisode;
    seconds = initialSeconds;
    onTick();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds <= 1) {
        timer.cancel();
        _timer = null;
        final finished = episode;
        episode = null;
        seconds = 0;
        onTick();
        if (finished != null) onComplete(finished);
      } else {
        seconds--;
        onTick();
      }
    });
  }

  bool cancel() {
    _timer?.cancel();
    _timer = null;
    if (episode == null && seconds == 0) return false;
    episode = null;
    seconds = 0;
    return true;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
