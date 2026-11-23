import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/database/secure_vault.dart';
import 'source_models.dart';

/// Keeps authorized headers out of native player logging and limits them to one origin.
class PlaybackRelay {
  PlaybackRelay._(this._server, this._http, this._root, this._headers);

  final HttpServer _server;
  final Dio _http;
  final Uri _root;
  final Map<String, String> _headers;
  final _secret = randomIdentifier();
  final _requests = <String, Uri>{};
  final _cancel = CancelToken();
  late final Uri uri;

  static Future<PlaybackRelay> open(StreamAccess upstream, Dio http) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = PlaybackRelay._(server, http, upstream.uri, upstream.headers);
    relay.uri = relay._local(upstream.uri);
    server.listen((request) => unawaited(relay._handle(request)));
    return relay;
  }

  Uri _local(Uri upstream) {
    if (!(upstream.isScheme('http') || upstream.isScheme('https')) ||
        !upstream.hasAuthority ||
        upstream.origin != _root.origin ||
        upstream.authority.contains('@')) {
      throw const FormatException('跨域的受保护媒体资源');
    }
    final existing = _requests.entries
        .where((entry) => entry.value == upstream)
        .firstOrNull;
    if (existing == null && _requests.length >= 8192) {
      throw const FormatException('媒体清单过大');
    }
    final id = existing?.key ?? _requests.length.toString();
    _requests[id] = upstream;
    final ext = upstream.path.endsWith('.m3u8') ? '.m3u8' : '';
    return Uri.parse('http://127.0.0.1:${_server.port}/$_secret/$id$ext');
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final parts = request.uri.pathSegments;
    final target = parts.length == 2 && parts.first == _secret
        ? _requests[parts.last.split('.').first]
        : null;
    if (target == null || request.method != 'GET') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    try {
      final range = request.headers.value('range');
      final upstream = await _http.getUri<ResponseBody>(
        target,
        cancelToken: _cancel,
        options: Options(
          headers: {
            ..._headers,
            'Accept-Encoding': 'identity',
            'Range': ?range,
          },
          responseType: ResponseType.stream,
          followRedirects: false,
        ),
      );
      final body = upstream.data;
      if (body == null) throw const FormatException('空媒体响应');
      final mime = upstream.headers.value('content-type')?.toLowerCase() ?? '';
      final playlist =
          mime.contains('mpegurl') || target.path.endsWith('.m3u8');
      if (playlist) {
        final bytes = <int>[];
        await for (final chunk in body.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 768 * 1024) throw const FormatException('媒体清单过大');
        }
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        response.write(_rewrite(utf8.decode(bytes), target));
      } else {
        response.statusCode = upstream.statusCode ?? 200;
        for (final key in [
          'content-type',
          'content-length',
          'content-range',
          'accept-ranges',
        ]) {
          final value = upstream.headers.value(key);
          if (value != null) response.headers.set(key, value);
        }
        await response.addStream(body.stream);
      }
    } on Exception {
      try {
        response.statusCode = HttpStatus.badGateway;
      } on StateError {
        // A streaming response may already have sent headers.
      }
    } finally {
      try {
        await response.close();
      } on Exception {
        // The video engine can close a range request when the user seeks.
      }
    }
  }

  String _rewrite(String contents, Uri origin) {
    if (!contents.trimLeft().startsWith('#EXTM3U')) {
      throw const FormatException('HLS 清单无效');
    }
    final uriAttribute = RegExp(r'URI="([^"]+)"');
    return const LineSplitter()
        .convert(contents)
        .map((line) {
          final value = line.trim();
          if (value.isEmpty) return '';
          if (!value.startsWith('#')) {
            return _local(origin.resolve(value)).toString();
          }
          if (value.startsWith('#EXT-X-SESSION-KEY') ||
              value.startsWith('#EXT-X-CONTENT-STEERING') ||
              value.startsWith('#EXT-X-DEFINE') ||
              (value.startsWith('#EXT-X-KEY:') &&
                  value != '#EXT-X-KEY:METHOD=NONE')) {
            throw const FormatException('不支持此类加密清单');
          }
          return value.replaceAllMapped(
            uriAttribute,
            (match) => 'URI="${_local(origin.resolve(match.group(1)!))}"',
          );
        })
        .join('\n');
  }

  Future<void> close() async {
    _cancel.cancel();
    await _server.close(force: true);
  }
}
