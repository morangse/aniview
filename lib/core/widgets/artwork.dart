import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../network/bangumi_http.dart';
import '../theme/app_theme.dart';

const localArtwork = 'assets/art/lakeside.webp';
const mistArtwork = 'assets/art/mist.webp';

final _artworkDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
      followRedirects: false,
      headers: {'User-Agent': BangumiHttp.userAgent},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final _artworkFileProvider = FutureProvider.autoDispose.family<File?, Uri>((
  ref,
  uri,
) async {
  final dio = ref.watch(_artworkDioProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  try {
    final folder = Directory(
      p.join((await getTemporaryDirectory()).path, 'bangumi-art-v1'),
    );
    final hash = sha256.convert(utf8.encode(uri.toString()));
    final target = File(p.join(folder.path, '$hash.img'));
    if (await target.exists()) return target;
    final result = await dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(responseType: ResponseType.stream),
    );
    final body = result.data;
    if (body == null) return null;
    final mime = result.headers.value(Headers.contentTypeHeader) ?? '';
    if (!mime.startsWith('image/')) {
      await body.stream.listen((_) {}).cancel();
      return null;
    }
    const maxBytes = 4 * 1024 * 1024;
    final chunks = <int>[];
    await for (final chunk in body.stream) {
      if (chunks.length + chunk.length > maxBytes) return null;
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty || cancel.isCancelled) return null;
    await folder.create(recursive: true);
    final temp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsBytes(chunks);
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    await _trimArtwork(folder, target.path);
    return target;
  } on DioException {
    return null;
  } on FileSystemException {
    return null;
  } on Exception {
    // A missing platform cache or disposed request still has a visual fallback.
    return null;
  }
}, retry: (_, _) => null);

Future<void> _trimArtwork(Directory folder, String current) async {
  final files = <(File, FileStat)>[];
  var size = 0;
  await for (final entry in folder.list()) {
    if (entry is! File || !entry.path.endsWith('.img')) continue;
    final stat = await entry.stat();
    size += stat.size;
    files.add((entry, stat));
  }
  const budget = 48 * 1024 * 1024;
  if (size <= budget) return;
  files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  for (final (file, stat) in files) {
    if (file.path == current) continue;
    if (await file.exists()) await file.delete();
    size -= stat.size;
    if (size <= budget) break;
  }
}

class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    this.uri,
    this.asset,
    this.decodeWidth = 320,
    this.alignment = Alignment.center,
  });

  final Uri? uri;
  final String? asset;
  final int decodeWidth;
  final Alignment alignment;

  static const placeholder = ColoredBox(
    color: ColorTokens.elevated,
    child: Center(child: Icon(Icons.image_outlined, color: ColorTokens.muted)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = this.uri;
    final file = uri != null && uri.isScheme('https')
        ? ref.watch(_artworkFileProvider(uri)).value
        : null;
    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: alignment,
        cacheWidth: decodeWidth,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (asset != null) {
      return Image.asset(
        asset!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: alignment,
        cacheWidth: decodeWidth,
        excludeFromSemantics: true,
      );
    }
    return const SizedBox.expand(child: placeholder);
  }
}

class MistBackdrop extends StatelessWidget {
  const MistBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: SizedBox(
      height: LayoutTokens.mistHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Artwork(
              asset: mistArtwork,
              decodeWidth: 192,
              alignment: Alignment.topCenter,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .44, 1],
                colors: [
                  Color(0xAC101923),
                  Color(0xB9101923),
                  ColorTokens.background,
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
