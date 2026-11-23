import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef PlaybackTrack = ({String id, String label});
typedef PlaybackSubtitle = PlaybackTrack;

class PlaybackViewState {
  const PlaybackViewState({
    this.opening = true,
    this.buffering = false,
    this.playing = false,
    this.completed = false,
    this.volume = 100,
    this.rate = 1,
    this.aspectRatio = 16 / 9,
    this.subtitles = const [],
    this.selectedSubtitle = 'auto',
    this.audioTracks = const [],
    this.selectedAudio = 'auto',
    this.error,
    this.storageError = false,
  });

  final bool opening;
  final bool buffering;
  final bool playing;
  final bool completed;
  final double volume;
  final double rate;
  final double aspectRatio;
  final List<PlaybackSubtitle> subtitles;
  final String selectedSubtitle;
  final List<PlaybackTrack> audioTracks;
  final String selectedAudio;
  final String? error;
  final bool storageError;

  bool get ready => !opening && error == null;
}

abstract interface class PlaybackController
    implements ValueListenable<PlaybackViewState> {
  ValueListenable<Duration> get positionListenable;
  ValueListenable<Duration> get durationListenable;
  Widget buildSurface();
  Future<void> open({required bool autoplay});
  Future<void> toggle();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);
  Future<void> setAudioTrack(String id);
  Future<void> setSubtitle(String id);
  Future<void> setExternalSubtitle({
    required String payload,
    required String title,
  });
  Future<void> clearExternalSubtitle();
  Future<void> setSubtitleDelayMs(int offsetMs);
  Future<void> saveProgress();
  Future<void> close();
}
