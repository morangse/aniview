import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart';

class CatalogFailure implements Exception {
  const CatalogFailure(this.message, {this.transient = false});

  final String message;
  final bool transient;

  @override
  String toString() => message;
}

class BangumiHttp {
  BangumiHttp(this._dio);

  static const developer = String.fromEnvironment(
    'BANGUMI_DEVELOPER',
    defaultValue: 'ran',
  );
  static const project = String.fromEnvironment('BANGUMI_PROJECT_URL');
  static const userAgent = '$developer/AniView/0.2.5 (Android)$projectSuffix';
  static const projectSuffix = project == '' ? '' : ' ($project)';

  final Dio _dio;

  static Dio createClient() => Dio(
    BaseOptions(
      baseUrl: 'https://api.bgm.tv',
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
      headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> request(
    String path, {
    required Map<String, Object> query,
    Map<String, Object>? body,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _dio.request<Object?>(
          path,
          queryParameters: query,
          data: body,
          options: Options(method: body == null ? 'GET' : 'POST'),
        );
        final payload = response.data;
        if (payload is! Map<String, dynamic>) {
          throw const CatalogFailure('Bangumi 返回的数据格式有误。');
        }
        return payload;
      } on DioException catch (error) {
        final code = error.response?.statusCode;
        final timeout = {
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        }.contains(error.type);
        final transient =
            timeout ||
            error.type == DioExceptionType.connectionError ||
            (code != null && code >= 500);
        if (transient && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        String message;
        if (code == 429) {
          final retryAfter = error.response?.headers.value('retry-after');
          if (retryAfter != null) {
            final seconds = int.tryParse(retryAfter);
            if (seconds != null) {
              message = '请求过于频繁，请 $seconds 秒后再试。';
            } else {
              try {
                final date = HttpDate.parse(retryAfter);
                final wait = date.difference(DateTime.now().toUtc());
                if (wait.inSeconds > 0) {
                  message = '请求过于频繁，请 ${wait.inSeconds} 秒后再试。';
                } else {
                  message = '请求过于频繁，请稍后再试。';
                }
              } catch (_) {
                message = '请求过于频繁，请稍后再试。';
              }
            }
          } else {
            message = '请求过于频繁，请稍后再试。';
          }
        } else if (code == 404) {
          message = 'Bangumi 上找不到该条目。';
        } else if (code == 400 || code == 422) {
          message = 'Bangumi 无法处理这组查询条件。';
        } else if (timeout) {
          message = '连接 Bangumi 超时，请重试。';
        } else if (transient) {
          message = '暂时无法连接 Bangumi，请检查网络后重试。';
        } else {
          message = '无法读取 Bangumi 数据，请稍后重试。';
        }

        throw CatalogFailure(message, transient: transient || code == 429);
      }
    }
  }
}
