import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../media/media.dart';
import '../../media/playback_controller.dart';
import '../../media/sources/media_pipeline.dart';
import '../../media/sources/playback_relay.dart';
import '../../media/sources/source_models.dart';
import 'player_panels.dart';

typedef SessionPlaybackFactory = PlaybackController Function(
  MediaCandidate,
  WatchProgressRepository,
);

class PlayerSessionController extends ChangeNotifier {
  PlayerSessionController({
    required this.candidate,
    required this.progress,
    required this.factory,
    required this.resolver,
    this.session,
    required this.onPlayingActive,
    required this.onCompletedChanged,
    required this.onFailoverNavigate,
  });

  final MediaCandidate candidate;
  final WatchProgressRepository progress;
  final SessionPlaybackFactory factory;
  final MediaResolver resolver;
  final PlaybackSession? session;
  final VoidCallback onPlayingActive;
  final ValueChanged<bool> onCompletedChanged;
  final ValueChanged<String> onFailoverNavigate;

  PlaybackController? controller;
  Widget? surface;
  PlaybackController? _retiring;
  PlaybackRelay? _relay;
  MediaLinkState? _link;
  String? backendError;
  bool switching = false;
  bool _failed = false;
  bool _recorded = false;
  bool _buffering = false;
  bool _wasCompleted = false;
  bool _disposed = false;
  final _startup = Stopwatch();

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open({required bool autoplay}) async {
    if (_disposed) return;
    _startup
      ..reset()
      ..start();
    try {
      final opened = await PlayerSessionHelper.openSessionTarget(
        resolver,
        candidate,
        session,
      );
      if (_disposed) {
        await opened.relay?.close();
        return;
      }
      _link = opened.link;
      _relay = opened.relay;
      final sessionProgress = session?.resumeAt == null
          ? progress
          : SessionWatchProgress(
              progress,
              session!.resumeAt!,
              session!.previousDuration,
            );
      final nextController = factory(
        candidate.withUri(opened.uri),
        sessionProgress,
      );
      nextController.addListener(_observe);
      controller = nextController;
      surface = nextController.buildSurface();
      _safeNotify();
      await nextController.open(autoplay: autoplay);
    } on SourceIssue catch (error) {
      if (_disposed) return;
      backendError = error.label;
      _safeNotify();
      await failover(error.label, sourceState: error.state);
    } on Object {
      if (_disposed) return;
      const error = '当前片源无法打开。请检查网络、文件权限或播放格式。';
      backendError = error;
      _safeNotify();
      await failover(error);
    }
  }

  void _observe() {
    final state = controller?.value;
    if (_disposed || state == null) return;
    if (state.error case final error?) {
      unawaited(failover(error));
      return;
    }
    if (state.playing) onPlayingActive();
    if (_link case final link?) {
      if (state.ready && !_recorded) {
        _recorded = true;
        _startup.stop();
        unawaited(
          PlayerSessionHelper.recordSuccess(
            resolver,
            candidate,
            link,
            _startup.elapsedMilliseconds,
          ),
        );
      }
      if (_recorded && state.buffering && !_buffering) {
        unawaited(
          resolver.store
              .recordHealth(link.key, SourceState.available, buffers: 1)
              .catchError((Object _) {}),
        );
      }
    }
    _buffering = state.buffering;
    if (state.completed != _wasCompleted) {
      _wasCompleted = state.completed;
      onCompletedChanged(state.completed);
    }
  }

  Future<void> failover(
    String error, {
    SourceState sourceState = SourceState.failed,
  }) async {
    if (_failed || _disposed) return;
    _failed = true;
    switching = session != null;
    _safeNotify();
    try {
      final next = await PlayerSessionHelper.advanceFailover(
        resolver: resolver,
        session: session,
        record: _link,
        error: error,
        sourceState: sourceState,
        controller: controller,
      );
      if (_disposed) return;
      if (next == null) {
        switching = false;
        _safeNotify();
      } else {
        onFailoverNavigate(next.id);
      }
    } on Exception {
      if (_disposed) return;
      switching = false;
      _safeNotify();
    }
  }

  Future<void> retry({required bool autoplay}) async {
    if (_retiring != null || _disposed) return;
    final previous = controller;
    previous?.removeListener(_observe);
    _retiring = previous;
    controller = null;
    surface = null;
    backendError = null;
    _safeNotify();
    await WidgetsBinding.instance.endOfFrame;
    try {
      await previous?.close();
      await _relay?.close();
      _relay = null;
    } on Object {
      // A new native player can still recover from a failed disposal.
    }
    if (_disposed) return;
    _retiring = null;
    _failed = false;
    _recorded = false;
    _wasCompleted = false;
    _safeNotify();
    unawaited(open(autoplay: autoplay));
  }

  static Future<void> _closeResources(
    PlaybackController? activeController,
    PlaybackRelay? activeRelay,
  ) async {
    try {
      await activeController?.close();
    } finally {
      await activeRelay?.close();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final activeController = controller;
    final activeRelay = _relay;
    controller = null;
    _relay = null;
    activeController?.removeListener(_observe);
    if (activeController != null || activeRelay != null) {
      unawaited(_closeResources(activeController, activeRelay));
    }
    super.dispose();
  }
}
