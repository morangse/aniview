import 'dart:io';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/features/anime/anime.dart';
import 'package:aniview/media/media.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorites, episode sources, settings and progress survive a database reopen', () async {
    final folder = await Directory.systemTemp.createTemp('aniview-test');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}${Platform.pathSeparator}aniview.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    final library = LocalLibrary(first);
    const anime = Anime(
      id: 21,
      originalName: 'Test subject',
      chineseName: '测试条目',
    );
    const firstEp = Episode(id: 30, number: 1, title: 'first');
    const secondEp = Episode(id: 31, number: 2, title: 'second');
    MediaCandidate candidate(Episode episode) => MediaCandidate.create(
      uri: Uri.parse('content://test.source/video.mp4'),
      kind: MediaKind.document,
      sourceName: 'capture.mp4',
      request: MediaRequest(anime: anime, episode: episode),
    );
    final one = candidate(firstEp);
    final two = candidate(secondEp);
    expect(one.id, isNot(two.id));
    await library.addMedia(one);
    await library.addMedia(two);
    await library.setFavorite(anime, true);
    await library.setAutoplay(false);
    final watchedAt = DateTime(2026, 11, 18, 18);
    await library.save(
      one.id,
      WatchProgress(
        position: const Duration(seconds: 40),
        duration: const Duration(minutes: 2),
        completed: false,
        updatedAt: watchedAt,
      ),
    );
    await library.save(
      one.id,
      WatchProgress(
        position: const Duration(seconds: 10),
        duration: const Duration(minutes: 2),
        completed: false,
        updatedAt: watchedAt.subtract(const Duration(seconds: 1)),
      ),
    );
    await library.save(
      two.id,
      WatchProgress(
        position: const Duration(minutes: 3),
        duration: const Duration(minutes: 2),
        completed: true,
        updatedAt: watchedAt.add(const Duration(seconds: 1)),
      ),
    );
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final restored = LocalLibrary(second);
    expect(await restored.watchAutoplay().first, false);
    expect((await restored.watchFavorites().first).single.title, anime.title);
    expect(
      (await restored.candidates(
        const MediaRequest(anime: anime, episode: firstEp),
      )).single.id,
      one.id,
    );
    expect(
      (await restored.candidates(const MediaRequest(anime: anime))).length,
      2,
    );
    expect((await restored.mediaById(two.id))?.episodeLabel, '第 2 集');
    final history = await restored.watchHistory().first;
    expect(history.map((entry) => entry.media.id), [two.id, one.id]);
    expect(history.first.progress.fraction, 1);
    expect(history.first.progress.resumePosition, Duration.zero);
    expect(
      (await restored.load(one.id))?.resumePosition,
      const Duration(seconds: 40),
    );
    await restored.setFavorite(anime, false);
    expect(await restored.watchFavorites().first, isEmpty);
    expect(await restored.watchHistory().first, hasLength(2));
  });

  test('5-state collections, rating and comment persist and preserve addedAt', () async {
    final folder = await Directory.systemTemp.createTemp('aniview-collections');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}${Platform.pathSeparator}aniview.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    final library = LocalLibrary(first);
    const anime = Anime(
      id: 99,
      originalName: 'Collection Anime',
      chineseName: '五态收藏测试',
    );
    await library.setCollection(
      anime,
      CollectionStatus.collected,
      rating: 9,
      comment: '  经典之作  ',
    );
    final initial = (await library.watchFavoriteEntries().first).single;
    expect(initial.status, CollectionStatus.collected);
    expect(initial.rating, 9);
    expect(initial.comment, '经典之作');
    expect(initial.dirty, true);

    await library.setCollection(
      anime,
      CollectionStatus.onHold,
      rating: 12,
      comment: '   ',
    );
    await library.clearFavoriteDirty(anime.id);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final restored = LocalLibrary(second);
    final loaded = (await restored.watchFavoriteEntries().first).single;
    expect(loaded.status, CollectionStatus.onHold);
    expect(loaded.rating, isNull);
    expect(loaded.comment, isNull);
    expect(loaded.dirty, false);
    expect(loaded.addedAt, initial.addedAt);
  });
}
