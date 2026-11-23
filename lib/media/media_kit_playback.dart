import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media.dart';
import 'playback_controller.dart';
import 'subtitle_fonts.dart';

class MediaKitPlayback extends ValueNotifier<PlaybackViewState>
    implements PlaybackController {
  MediaKitPlayback(this.media, this.progress)
    : super(const PlaybackViewState()) {
    MediaKit.ensureInitialized();
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'AniView',
        libass: true,
        libassAndroidFont: SubtitleFontConfig.bundledAsset,
        libassAndroidFontName: SubtitleFontConfig.bundledFontName,
      ),
    );
    _video = VideoController(_player);
    final events = _player.stream;
    for (final stream in <Stream<dynamic>>[
      events.playing,
      events.buffering,
      events.volume,
      events.rate,
      events.track,
      events.tracks,
    ]) {
      _listeners.add(stream.listen((_) => _publish()));
    }
    _listeners.add(
      events.position.listen((position) {
        if (!_closed && _position.value != position) {
          _position.value = position;
        }
      }),
    );
    _listeners.add(
      events.duration.listen((duration) {
        if (!_closed && _duration.value != duration) {
          _duration.value = duration;
        }
      }),
    );
    _listeners.add(
      events.completed.listen((completed) {
        _publish();
        if (completed) unawaited(saveProgress());
      }),
    );
    _listeners.add(events.error.listen((_) => _fail()));
  }

  final MediaCandidate media;
  final WatchProgressRepository progress;
  late final Player _player;
  late final VideoController _video;
  final _listeners = <StreamSubscription<dynamic>>[];
  final _failed = Completer<void>();
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _duration = ValueNotifier<Duration>(Duration.zero);
  Timer? _checkpoint;

  @override
  ValueListenable<Duration> get positionListenable => _position;

  @override
  ValueListenable<Duration> get durationListenable => _duration;
  String? _problem;
  bool _opening = true;
  bool _closed = false;
  bool _storageError = false;
  bool _changed = false;
  bool _externalSubtitleActive = false;
  WatchProgress? _lastSaved;
  Future<void> _writes = Future.value();

  @override
  Widget buildSurface() => Video(
    controller: _video,
    fit: BoxFit.contain,
    controls: NoVideoControls,
    pauseUponEnteringBackgroundMode: false,
    subtitleViewConfiguration: const SubtitleViewConfiguration(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 36),
    ),
  );

  @override
  Future<void> open({required bool autoplay}) async {
    try {
      _lastSaved = await progress.load(media.id);
    } on Exception {
      _storageError = true;
    }
    if (_closed) return;
    try {
      await _configureNativeOptions();
      final start = _lastSaved?.resumePosition;
      await _player
          .open(Media(media.uri.toString(), start: start), play: autoplay)
          .timeout(const Duration(seconds: 15));
      await Future.any([_video.waitUntilFirstFrameRendered, _failed.future])
          .timeout(const Duration(seconds: 16));
      if (_closed || _problem != null) return;
      _position.value = _player.state.position;
      _duration.value = _player.state.duration;
      _opening = false;
      _checkpoint = Timer.periodic(
        const Duration(seconds: 4),
        (_) => saveProgress(),
      );
      _publish();
    } on Exception {
      _fail();
    }
  }

  Future<void> _configureNativeOptions() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('volume-max', '150');
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !(await SubtitleFontConfig.hasBundledFont())) {
        await platform.setProperty(
          'sub-fonts-dir',
          SubtitleFontConfig.androidFallbackFontsDir,
        );
        await platform.setProperty(
          'sub-font',
          SubtitleFontConfig.androidFallbackFontName,
        );
      }
    } on Object {
      // Property configuration is best-effort across backends/devices.
    }
  }

  void _fail() {
    if (_closed || _problem != null) return;
    unawaited(saveProgress());
    _opening = false;
    _problem = media.kind == MediaKind.document
        ? '无法读取视频。文件可能已移动、权限已失效，或编码暂不受支持。'
        : '无法加载视频。请检查地址、访问权限和网络，或换一个 MP4/HLS 片源。';
    _checkpoint?.cancel();
    if (!_failed.isCompleted) _failed.complete();
    _publish();
    unawaited(_player.pause().catchError((Object _) {}));
  }

  static String _trackLabel(String? title, String? language) =>
      [title, language].nonNulls.where((text) => text.isNotEmpty).join(' · ');

  void _publish() {
    if (_closed) return;
    final state = _player.state;
    final width = state.width ?? 0;
    final height = state.height ?? 0;
    final subTracks = state.tracks.subtitle.where(
      (track) => track.id != 'auto' && track.id != 'no',
    );
    final audioTracks = state.tracks.audio.where(
      (track) => track.id != 'auto' && track.id != 'no',
    );
    value = PlaybackViewState(
      opening: _opening,
      buffering: state.buffering,
      playing: state.playing,
      completed: state.completed,
      volume: state.volume,
      rate: state.rate,
      aspectRatio: width > 0 && height > 0 ? width / height : 16 / 9,
      subtitles: subTracks
          .map(
            (track) => (
              id: track.id,
              label: _trackLabel(track.title, track.language),
            ),
          )
          .toList(growable: false),
      selectedSubtitle: state.track.subtitle.id,
      audioTracks: audioTracks
          .map(
            (track) => (
              id: track.id,
              label: _trackLabel(track.title, track.language),
            ),
          )
          .toList(growable: false),
      selectedAudio: state.track.audio.id,
      error: _problem,
      storageError: _storageError,
    );
  }

  @override
  Future<void> toggle() async {
    if (_closed || !value.ready) return;
    if (_player.state.playing) {
      await pause();
    } else {
      if (_player.state.completed) await _player.seek(Duration.zero);
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_closed) return;
    await _player.pause();
    await saveProgress();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_closed || !value.ready || _duration.value == Duration.zero) return;
    _changed = true;
    await _player.seek(position);
  }

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 150.0).toDouble());

  @override
  Future<void> setAudioTrack(String id) async {
    if (_closed) return;
    final track = switch (id) {
      'auto' => AudioTrack.auto(),
      'no' => AudioTrack.no(),
      _ =>
        _player.state.tracks.audio.where((item) => item.id == id).firstOrNull,
    };
    if (track != null) await _player.setAudioTrack(track);
  }

  @override
  Future<void> setSubtitle(String id) async {
    final track = switch (id) {
      'auto' => SubtitleTrack.auto(),
      'no' => SubtitleTrack.no(),
      _ =>
        _player.state.tracks.subtitle
            .where((item) => item.id == id)
            .firstOrNull,
    };
    if (track != null) {
      _externalSubtitleActive = false;
      await _player.setSubtitleTrack(track);
    }
  }

  @override
  Future<void> setExternalSubtitle({
    required String payload,
    required String title,
  }) async {
    if (_closed) return;
    _externalSubtitleActive = true;
    await _player.setSubtitleTrack(SubtitleTrack.data(payload, title: title));
  }

  @override
  Future<void> clearExternalSubtitle() async {
    if (_closed || !_externalSubtitleActive) return;
    _externalSubtitleActive = false;
    await _player.setSubtitleTrack(SubtitleTrack.auto());
  }

  @override
  Future<void> setSubtitleDelayMs(int offsetMs) async {
    if (_closed) return;
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    await platform.setProperty(
      'sub-delay',
      (offsetMs / 1000.0).toStringAsFixed(3),
    );
  }

  @override
  Future<void> saveProgress() {
    if (_closed || _opening || _problem != null) return _writes;
    final state = _player.state;
    final duration = state.duration;
    final previous = _lastSaved;
    if (duration <= Duration.zero) return _writes;
    final position = state.completed ? duration : state.position;
    if (position > Duration.zero) _changed = true;
    if (!_changed ||
        (previous?.position == position &&
            previous?.completed == state.completed)) {
      return _writes;
    }
    final record = WatchProgress(
      position: position,
      duration: duration,
      completed: state.completed,
      updatedAt: DateTime.now(),
    );
    _lastSaved = record;
    _writes = _writes.then((_) async {
      try {
        await progress.save(media.id, record);
        if (_storageError) {
          _storageError = false;
          _publish();
        }
      } on Exception {
        if (identical(_lastSaved, record)) _lastSaved = null;
        _storageError = true;
        _publish();
      }
    });
    return _writes;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    final pending = saveProgress();
    _closed = true;
    _checkpoint?.cancel();
    if (!_failed.isCompleted) _failed.complete();
    await Future.wait(_listeners.map((listener) => listener.cancel()));
    try {
      await _player.dispose();
    } finally {
      await pending;
      _position.dispose();
      _duration.dispose();
      dispose();
    }
  }
}
