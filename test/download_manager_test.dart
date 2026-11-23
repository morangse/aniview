import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:aniview/core/database/app_database.dart';
import 'package:aniview/core/database/local_library.dart';
import 'package:aniview/media/downloads/download_manager.dart';
import 'package:aniview/media/sources/media_pipeline.dart';
import 'package:aniview/media/sources/source_adapters.dart';
import 'package:aniview/media/sources/source_models.dart';
import 'package:aniview/media/sources/source_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault.dart';

void main() {
  test('interrupted download survives manager restart, resumes with Range and opens offline', () async {
    final setup = await _fixture();
    var interrupt = true;
    String? resumeRange;
    setup.http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final range = options.headers['Range'] as String?;
          final rangeOffset = range == null
              ? 0
              : int.parse(range.split(RegExp('[=-]'))[1]);
          if (range != null) resumeRange = range;
          final headers = {
            'content-type': ['video/mp4'],
            'etag': ['"version1"'],
            'content-length': ['${setup.bytes.length - rangeOffset}'],
            if (range != null)
              'content-range': [
                'bytes $rangeOffset-${setup.bytes.length - 1}/${setup.bytes.length}',
              ],
          };
          final status = range == null ? 200 : 206;
          Stream<Uint8List> body() async* {
            if (interrupt) {
              yield Uint8List.sublistView(setup.bytes, 0, 64);
              throw const SocketException('QA connection interrupted');
            }
            yield Uint8List.sublistView(setup.bytes, rangeOffset);
          }

          handler.resolve(
            Response(
              requestOptions: options,
              data: ResponseBody(body(), status, headers: headers),
              statusCode: status,
              headers: Headers.fromMap(headers),
            ),
          );
        },
      ),
    );
    final manager = setup.manager();
    final id = await manager.enqueue('direct');
    var task = (await manager.watch().first).single;
    expect(task.state, 'failed');
    expect(task.received, 64);
    expect(task.validator, '"version1"');
    await setup.db
        .into(setup.db.downloadTasks)
        .insertOnConflictUpdate(task.copyWith(state: 'running'));
    final restarted = setup.manager();
    expect((await restarted.watch().first).single.state, 'paused');
    interrupt = false;
    await restarted.resume(id);
    expect(resumeRange, 'bytes=64-');
    task = (await restarted.watch().first).single;
    expect(task.state, 'complete');
    final media = await restarted.offlineMedia(task);
    expect(await File.fromUri(media.uri).readAsBytes(), setup.bytes);
    final changed = Uint8List.fromList(setup.bytes)..[100] = 7;
    await File.fromUri(media.uri).writeAsBytes(changed);
    await expectLater(
      restarted.offlineMedia(task),
      throwsA(isA<SourceIssue>()),
    );
    expect((await restarted.watch().first).single.state, 'failed');
  });

  test('insufficient disk space fails before writing and incomplete files never open', () async {
    final setup = await _fixture();
    setup.http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final headers = {
            'content-type': ['video/mp4'],
            'content-length': ['${setup.bytes.length}'],
          };
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromBytes(setup.bytes, 200, headers: headers),
              headers: Headers.fromMap(headers),
            ),
          );
        },
      ),
    );
    final manager = setup.manager(free: 1);
    await manager.enqueue('direct');
    final task = (await manager.watch().first).single;
    expect(task.state, 'failed');
    expect(task.error, contains('空间不足'));
    expect(await manager.storageBytes(), 0);
    await expectLater(manager.offlineMedia(task), throwsA(isA<SourceIssue>()));
  });
}

class _Fixture {
  _Fixture(this.db, this.http, this.resolver, this.folder);
  final AppDatabase db;
  final Dio http;
  final MediaResolver resolver;
  final Directory folder;
  final bytes = Uint8List.fromList([
    ..._box('ftyp', [105, 115, 111, 109]),
    ..._box('moov', [1, 2, 3, 4]),
    ..._box('mdat', List.filled(300, 0)),
  ]);

  DownloadManager manager({int free = 10000000}) =>
      DownloadManager(resolver, () async => folder, () async => free);

  static List<int> _box(String tag, List<int> bytes) => [
    0,
    0,
    (bytes.length + 8) >> 8,
    (bytes.length + 8) & 0xff,
    ...tag.codeUnits,
    ...bytes,
  ];
}

Future<_Fixture> _fixture() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dio = createMediaHttp();
  final folder = await Directory.systemTemp.createTemp('aniview-download');
  addTearDown(() async {
    await db.close();
    dio.close();
    await folder.delete(recursive: true);
  });
  final store = SourceStore(db, TestVault());
  final library = LocalLibrary(db);
  final registry = MediaSourceRegistry(store, library, dio);
  await store.put(
    const ConfiguredSource(
      id: 'direct',
      name: 'Allowed.mp4',
      kind: 'direct',
      endpoint: 'https://example.invalid',
      userId: '',
      enabled: true,
      priority: 0,
      offlineAllowed: true,
      subjectTitle: '',
    ),
    secret: {'url': 'https://example.invalid/owned.mp4'},
  );
  return _Fixture(db, dio, MediaResolver(registry, store, library), folder);
}
