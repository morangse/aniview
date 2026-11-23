import 'dart:convert';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/media/media.dart';
import 'package:aniview/media/overlays/danmaku_layout.dart';
import 'package:aniview/media/overlays/media_overlays.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  const srt =
      '1\n00:00:01,000 --> 00:00:03,010\n<i>测试</i>\n\n'
      '2\n00:00:02,000 --> 00:00:02,800\nSecond line\n';
  test('SRT overlaps, millisecond offsets and WebVTT positioning syntax', () {
    final subtitle = SubtitleManager.parse(srt, 'episode.zh-Hans.srt');
    expect(
      subtitle.textAt(const Duration(milliseconds: 2200)),
      '测试\nSecond line',
    );
    expect(
      subtitle.textAt(const Duration(milliseconds: 1100), offsetMs: 250),
      '',
    );
    expect(
      subtitle.textAt(const Duration(milliseconds: 850), offsetMs: -250),
      '测试',
    );
    expect(
      SubtitleManager.stem('episode.zh-Hans.srt'),
      SubtitleManager.stem('episode.mp4'),
    );
    expect(
      SubtitleManager.parse(
        'WEBVTT\n\n00:01.000 --> 00:02.000 align:start\nOne\n',
        'sub.vtt',
      ).textAt(const Duration(milliseconds: 1250)),
      'One',
    );
    expect(() => decodeAttachment([0xff, 0x02, 0xff]), throwsFormatException);
    expect(decodeAttachment([0xff, 0xfe, 65, 0]), 'A');
  });

  test(
    'local danmaku has three modes, blocks words and caps the visible count',
    () {
      final track = DanmakuTrack.parse(
        '<i><d p="1,1">scroll</d><d p="1,5">top</d>'
            '<d p="1,4">bottom</d><d p="1,7">advanced</d></i>',
        'known.xml',
      );
      expect(
        track.items.map((row) => row.mode).toSet(),
        DanmakuMode.values.toSet(),
      );
      expect(track.visible(1200, 1000, 1, ['SCROLL']).single.text, 'top');
      expect(track.visible(5000, 1000, 30, []), isEmpty);
      expect(
        () => DanmakuTrack.parse('<!DOCTYPE i><i/>', 'bad.xml'),
        throwsFormatException,
      );
    },
  );

  test('subtitle binding and danmaku on/off are durable across source changes for one episode', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = OverlayStore(SourceStore(db, TestVault()));
    MediaCandidate media(String id) => MediaCandidate(
      id: id,
      uri: Uri.parse('https://test.invalid/media.mp4'),
      kind: MediaKind.direct,
      title: 'test',
      sourceName: '$id.mp4',
      subjectId: 1,
      episodeId: 10,
    );
    final original = media('one');
    final nextSource = media('two');
    final attachment = await store.add(
      original,
      'subtitle',
      'episode.srt',
      utf8.encode(srt),
    );
    final comments = await store.add(
      original,
      'danmaku',
      'comment.json',
      utf8.encode('[{"time":1,"mode":"scroll","text":"sample"}]'),
    );
    final config = {
      'subtitleId': attachment.id,
      'subtitleOffset': 250,
      'danmakuId': comments.id,
      'danmakuEnabled': false,
    };
    await store.save(original, config);
    final restored = await store.load(nextSource);
    expect(restored.subtitle?.cues, hasLength(2));
    expect(restored.settings.subtitleOffset, 250);
    expect(restored.settings.danmakuEnabled, false);
    await store.save(nextSource, {...config, 'danmakuEnabled': true});
    expect((await store.load(original)).settings.danmakuEnabled, true);
  });

  test(
    'danmaku parses XML/JSON colors and schedules 100 items without overlap or lane jump',
    () {
      final xmlTrack = DanmakuTrack.parse(
        '<i><d p="1,1,25,16711680">red</d><d p="1,1,25,bad">white</d></i>',
        'colors.xml',
      );
      expect(xmlTrack.items[0].color, 0xFFFF0000);
      expect(xmlTrack.items[1].color, 0xFFFFFFFF);

      final jsonTrack = DanmakuTrack.parse(
        '[{"time":1,"mode":"scroll","text":"hi","color":"#00FF88"}]',
        'colors.json',
      );
      expect(jsonTrack.items.single.color, 0xFF00FF88);

      final items = <DanmakuItem>[
        for (var i = 0; i < 6; i++)
          const DanmakuItem(1000, DanmakuMode.scroll, '666'),
        for (var i = 6; i < 90; i++)
          DanmakuItem(1000 + i * 55, DanmakuMode.scroll, 'comment-$i'),
        for (var i = 90; i < 95; i++)
          DanmakuItem(1000 + (i - 90) * 150, DanmakuMode.top, 'top-$i'),
        for (var i = 95; i < 100; i++)
          DanmakuItem(1000 + (i - 95) * 150, DanmakuMode.bottom, 'bot-$i'),
      ];
      final track = DanmakuTrack(items);
      final engine = DanmakuLayoutEngine();
      double measure(DanmakuItem item) => item.text.length * 14.0;

      final frame1 = engine.layout(
        track: track,
        ms: 1000,
        lifeMs: 6500,
        limit: 100,
        blocked: const [],
        viewportWidth: 800,
        viewportHeight: 420,
        fontSize: 16,
        measureWidth: measure,
      );
      final sameTextLanes = frame1
          .where((p) => p.item.text == '666')
          .map((p) => p.lane)
          .toList();
      expect(sameTextLanes, hasLength(6));
      expect(sameTextLanes.toSet(), hasLength(6));

      final laneByIndex = {for (final p in frame1) p.index: p.lane};

      final frame2 = engine.layout(
        track: track,
        ms: 1500,
        lifeMs: 6500,
        limit: 100,
        blocked: const [],
        viewportWidth: 800,
        viewportHeight: 420,
        fontSize: 16,
        measureWidth: measure,
      );
      for (final p in frame2) {
        if (laneByIndex.containsKey(p.index)) {
          expect(p.lane, laneByIndex[p.index]);
        }
      }

      // Verify no horizontal overlap in any scroll lane and no duplicate fixed lanes.
      final byScrollLane = <int, List<PlacedDanmaku>>{};
      final seenFixed = <(DanmakuMode, int)>{};
      for (final p in frame2) {
        if (p.item.mode == DanmakuMode.scroll) {
          byScrollLane.putIfAbsent(p.lane, () => []).add(p);
        } else {
          expect(seenFixed.add((p.item.mode, p.lane)), true);
        }
      }
      for (final laneItems in byScrollLane.values) {
        laneItems.sort((a, b) => a.left.compareTo(b.left));
        for (var i = 1; i < laneItems.length; i++) {
          final prev = laneItems[i - 1];
          final curr = laneItems[i];
          expect(prev.left + prev.width, lessThanOrEqualTo(curr.left + 0.01));
        }
      }

      // Seeking backward > 500ms resets layout cleanly.
      final rewound = engine.layout(
        track: track,
        ms: 1000,
        lifeMs: 6500,
        limit: 100,
        blocked: const [],
        viewportWidth: 800,
        viewportHeight: 420,
        fontSize: 16,
        measureWidth: measure,
      );
      expect(rewound.where((p) => p.item.text == '666'), hasLength(6));
    },
  );

  test(
    'external ASS/SSA subtitles validate and route cleanly alongside SRT',
    () async {
      const validAss =
          '[Script Info]\nScriptType: v4.00+\n[Events]\nDialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,测试字幕\n';
      expect(SubtitleManager.isAssFilename('ep01.ass'), true);
      expect(SubtitleManager.isAssFilename('ep01.SSA'), true);
      expect(SubtitleManager.isAssFilename('ep01.srt'), false);
      expect(
        () => SubtitleManager.validateAss(
          '[Script Info]\nTitle: Empty\n',
          'bad.ass',
        ),
        throwsFormatException,
      );

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = OverlayStore(SourceStore(db, TestVault()));
      final media = MediaCandidate(
        id: 'ass-1',
        uri: Uri.parse('https://test.invalid/ep01.mkv'),
        kind: MediaKind.direct,
        title: 'ASS Test',
        sourceName: 'ep01.mkv',
      );
      final assRow = await store.add(
        media,
        'subtitle',
        'fansub.ass',
        utf8.encode(validAss),
      );
      await store.save(media, {'subtitleId': assRow.id, 'subtitleOffset': 500});
      final loadedAss = await store.load(media);
      expect(loadedAss.subtitle, isNull);
      expect(loadedAss.assSubtitle?.id, assRow.id);
      expect(loadedAss.assSubtitle?.name, 'fansub.ass');
      expect(loadedAss.assSubtitle?.payload, validAss);
      expect(loadedAss.settings.subtitleOffset, 500);

      final srtRow = await store.add(
        media,
        'subtitle',
        'plain.srt',
        utf8.encode(srt),
      );
      await store.save(media, {'subtitleId': srtRow.id});
      final loadedSrt = await store.load(media);
      expect(loadedSrt.assSubtitle, isNull);
      expect(loadedSrt.subtitle?.cues, hasLength(2));
    },
  );
}
