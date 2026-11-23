import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../media.dart';
import '../sources/media_pipeline.dart';
import '../sources/source_models.dart';

enum DownloadState { queued, running, paused, failed, complete, canceled }

class DownloadManager {
  DownloadManager(this.resolver, this.directory, this.availableBytes);
  final MediaResolver resolver;
  final Future<Directory> Function() directory;
  final Future<int?> Function() availableBytes;
  final _active = <String, CancelToken>{};
  final _jobs = <String, Future<void>>{};
  Future<void>? _recovered;

  AppDatabase get _db => resolver.store.db;

  Future<void> recover() => _recovered ??= (() async {
    final task = _db.downloadTasks;
    await (_db.update(task)..where((row) => row.state.equals('running'))).write(
      const DownloadTasksCompanion(
        state: Value('paused'),
        error: Value('上次传输已中断'),
      ),
    );
  })();

  Stream<List<DownloadTask>> watch() async* {
    await recover();
    yield* _db.select(_db.downloadTasks).watch();
  }

  Future<DownloadTask?> _read(String id) => (_db.select(
    _db.downloadTasks,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
  Future<void> _save(DownloadTask task) async =>
      _db.into(_db.downloadTasks).insertOnConflictUpdate(task);

  Future<(ConfiguredSource, StreamAccess)> _authorized(String sourceId) async {
    final source = await resolver.store.byId(sourceId);
    if (source == null ||
        !source.enabled ||
        source.kind != 'direct' ||
        !source.offlineAllowed) {
      throw const SourceIssue(SourceState.forbidden, '该来源没有启用离线保存。');
    }
    final adapter = await resolver.registry.enabledAdapter(sourceId);
    final access = await adapter.resolve(sourceId);
    if (!access.uri.path.toLowerCase().endsWith('.mp4')) {
      throw const SourceIssue(SourceState.failed, '离线下载目前支持获得授权的 MP4 文件。');
    }
    return (source, access);
  }

  String _id(ConfiguredSource source, StreamAccess access) => sha256
      .convert(utf8.encode(jsonEncode([source.id, access.uri.toString()])))
      .toString();

  Future<String> enqueue(String sourceId) async {
    await recover();
    final (config, access) = await _authorized(sourceId);
    final id = _id(config, access);
    if (await _read(id) == null) {
      await _save(
        DownloadTask(
          id: id,
          sourceId: sourceId,
          title: config.name,
          state: 'queued',
          received: 0,
        ),
      );
    }
    await resume(id);
    return id;
  }

  Future<void> resume(String id) async {
    await recover();
    if (_active.containsKey(id)) return;
    if (_active.length >= 2) {
      throw const SourceIssue(SourceState.suspect, '一次最多下载两个视频。');
    }
    final token = CancelToken();
    _active[id] = token;
    final job = _run(id, token).whenComplete(() {
      _active.remove(id);
      _jobs.remove(id);
    });
    _jobs[id] = job;
    await job;
  }

  Future<void> pause(String id) async {
    _active[id]?.cancel('paused');
    await _jobs[id];
  }

  Future<void> cancel(String id) async {
    await pause(id);
    final task = await _read(id);
    if (task == null || task.state == 'complete') return;
    final folder = await directory();
    final part = _file(folder, id, part: true);
    if (await part.exists()) await part.delete();
    await _save(
      task.copyWith(
        state: 'canceled',
        received: 0,
        total: const Value(null),
        validator: const Value(null),
        error: const Value(null),
      ),
    );
  }

  Future<void> remove(String id) async {
    await pause(id);
    final folder = await directory();
    for (final part in [true, false]) {
      final file = _file(folder, id, part: part);
      if (await file.exists()) await file.delete();
    }
    await (_db.delete(
      _db.downloadTasks,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<int> storageBytes() async {
    final folder = await directory();
    if (!await folder.exists()) return 0;
    var total = 0;
    await for (final entry in folder.list()) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  Future<MediaCandidate> offlineMedia(DownloadTask task) async {
    final file = _file(await directory(), task.id);
    if (task.state != 'complete' ||
        !await file.exists() ||
        await sha256
                .bind(file.openRead())
                .first
                .then((hash) => hash.toString()) !=
            task.checksum) {
      await _save(
        task.copyWith(state: 'failed', error: const Value('离线文件缺失或已损坏，请重新下载。')),
      );
      throw const SourceIssue(SourceState.failed, '离线文件缺失或已损坏。');
    }
    final candidate = MediaCandidate.create(
      uri: file.uri,
      kind: MediaKind.document,
      sourceName: task.title,
      request: const MediaRequest(),
    );
    await resolver.library.addMedia(candidate);
    return candidate;
  }

  File _file(Directory folder, String id, {bool part = false}) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('下载任务 ID 无效');
    }
    return File(p.join(folder.path, '$id.${part ? 'part' : 'mp4'}'));
  }

  Future<void> _run(String id, CancelToken token) async {
    final saved = await _read(id);
    if (saved == null || saved.state == 'complete') return;
    var task = saved;
    RandomAccessFile? writer;
    File? partial;
    try {
      final (source, access) = await _authorized(task.sourceId);
      if (_id(source, access) != id) {
        throw const SourceIssue(SourceState.failed, '源地址已修改，请重新创建下载任务。');
      }
      final folder = await directory();
      await folder.create(recursive: true);
      final part = partial = _file(folder, id, part: true);
      final target = _file(folder, id);
      if (await target.exists()) {
        final proof = task.checksum;
        final intact =
            proof == null ||
            (await sha256.bind(target.openRead()).first).toString() == proof;
        if (intact &&
            task.total != null &&
            await target.length() == task.total &&
            await _regularMp4(target)) {
          await _complete(task, target);
          return;
        }
        await target.delete();
      }
      var offset = await part.exists() ? await part.length() : 0;
      if (task.validator == null) offset = 0;
      task = task.copyWith(
        state: 'running',
        received: offset,
        error: const Value(null),
      );
      await _save(task);
      final response = await resolver.registry.http.getUri<ResponseBody>(
        access.uri,
        cancelToken: token,
        options: Options(
          followRedirects: false,
          responseType: ResponseType.stream,
          headers: {
            ...access.headers,
            'Accept-Encoding': 'identity',
            if (offset > 0) 'Range': 'bytes=$offset-',
            if (offset > 0) 'If-Range': task.validator!,
          },
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const SourceIssue(SourceState.failed, '服务器没有返回文件。');
      }
      final contentType =
          response.headers.value('content-type')?.toLowerCase() ?? '';
      if (contentType.contains('text/') ||
          contentType.contains('json') ||
          contentType.contains('mpegurl')) {
        throw const SourceIssue(SourceState.failed, '该响应不是可保存的 MP4。');
      }
      final tag = response.headers.value('etag');
      final validator = tag != null && !tag.startsWith('W/')
          ? tag
          : response.headers.value('last-modified');
      int? total;
      if (response.statusCode == 206) {
        final contentRange = response.headers.value('content-range') ?? '';
        final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (match == null ||
            int.parse(match.group(1)!) != offset ||
            offset > 0 && validator != task.validator) {
          throw const SourceIssue(SourceState.suspect, '服务器返回的续传区间或版本不一致。');
        }
        total = int.parse(match.group(3)!);
      } else {
        offset = 0;
        total = int.tryParse(response.headers.value('content-length') ?? '');
      }
      if (total == null || total <= 0 || offset > total) {
        throw const SourceIssue(SourceState.failed, '服务器未提供可验证的文件长度。');
      }
      final free = await availableBytes();
      if (free != null && free < total - offset + 1024 * 1024) {
        throw const SourceIssue(SourceState.failed, '存储空间不足。');
      }
      task = task.copyWith(
        received: offset,
        total: Value(total),
        validator: Value(validator),
      );
      await _save(task);
      writer = await part.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      final heartbeat = Stopwatch()..start();
      await for (final chunk in body.stream) {
        if (token.isCancelled) break;
        received += chunk.length;
        if (received > total) {
          throw const SourceIssue(SourceState.failed, '文件长度与响应不一致。');
        }
        await writer.writeFrom(chunk);
        if (heartbeat.elapsedMilliseconds >= 450) {
          heartbeat.reset();
          task = task.copyWith(received: received);
          await _save(task);
        }
      }
      await writer.close();
      writer = null;
      if (token.isCancelled) {
        await _save(task.copyWith(state: 'paused', received: received));
        return;
      }
      if (received != total) {
        throw const SourceIssue(SourceState.suspect, '下载未收齐，可以重试。');
      }
      if (!await _regularMp4(part)) {
        await part.delete();
        throw const SourceIssue(SourceState.failed, 'MP4 容器已损坏、加密或格式不受支持。');
      }
      await part.rename(target.path);
      await _complete(task, target);
    } on Exception catch (error) {
      final latest = await _read(id);
      if (latest == null) return;
      final bytes = partial != null && await partial.exists()
          ? await partial.length()
          : 0;
      final reason = error is SourceIssue
          ? error.label
          : error is FileSystemException
          ? '无法写入下载文件，请检查存储空间。'
          : '网络传输中断，请重试或继续下载。';
      await _save(
        latest.copyWith(
          state: token.isCancelled ? 'paused' : 'failed',
          received: bytes,
          error: Value(token.isCancelled ? null : reason),
        ),
      );
    } finally {
      token.cancel();
      await writer?.close();
    }
  }

  Future<void> _complete(DownloadTask task, File target) async {
    final hash = await sha256.bind(target.openRead()).first;
    final size = await target.length();
    await _save(
      task.copyWith(
        state: 'complete',
        received: size,
        total: Value(size),
        checksum: Value(hash.toString()),
        error: const Value(null),
      ),
    );
  }
}

Future<bool> _regularMp4(File input) async {
  final reader = await input.open();
  try {
    final length = await reader.length();
    var offset = 0;
    var hasType = false;
    var hasMetadata = false;
    var hasData = false;
    while (offset < length) {
      await reader.setPosition(offset);
      final header = await reader.read(8);
      if (header.length != 8) return false;
      var size = ByteData.sublistView(header).getUint32(0);
      final name = ascii.decode(header.sublist(4, 8), allowInvalid: true);
      var headerLength = 8;
      if (size == 1) {
        final extended = await reader.read(8);
        if (extended.length != 8) return false;
        size = ByteData.sublistView(extended).getUint64(0);
        headerLength = 16;
      } else if (size == 0) {
        size = length - offset;
      }
      if (size < headerLength || size > length - offset || name == 'pssh') {
        return false;
      }
      if (name == 'ftyp') hasType = true;
      if (name == 'mdat') hasData = size > headerLength;
      if (name == 'moov') {
        if (size > 32 * 1024 * 1024) return false;
        final metadata = latin1.decode(await reader.read(size - headerLength));
        if (RegExp(r'pssh|sinf|tenc|encv|enca').hasMatch(metadata)) {
          return false;
        }
        hasMetadata = metadata.isNotEmpty;
      }
      offset += size;
    }
    return hasType && hasMetadata && hasData;
  } finally {
    await reader.close();
  }
}
