import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/local_library.dart';
import '../../core/database/secure_vault.dart';
import '../../core/network/bangumi_http.dart';
import '../../features/anime/anime.dart';
import 'bangumi_parser.dart';

class BangumiAccount {
  const BangumiAccount(this.username, this.name);
  final String username;
  final String name;
}

class OAuthPairing {
  const OAuthPairing(this.state, this.proof, this.authorizationUrl);
  final String state;
  final String proof;
  final Uri authorizationUrl;
}

class BangumiOAuthBridge {
  BangumiOAuthBridge(this.http, this.endpoint);
  final Dio http;
  final Uri? endpoint;

  bool get configured =>
      endpoint != null &&
      endpoint!.isScheme('https') &&
      endpoint!.hasAuthority &&
      endpoint!.userInfo.isEmpty;

  Future<OAuthPairing> begin() async {
    final proof = randomIdentifier(32);
    final reply = await _post('/auth/start', {
      'hash': sha256.convert(utf8.encode(proof)).toString(),
    });
    final state = reply['state'];
    final url = Uri.tryParse(reply['authorize_url'] as String? ?? '');
    if (state is! String ||
        url == null ||
        url.host != 'bgm.tv' ||
        !url.isScheme('https') ||
        url.path != '/oauth/authorize' ||
        url.queryParameters['state'] != state) {
      throw const CatalogFailure('授权服务返回了无效的 Bangumi 登录地址。');
    }
    return OAuthPairing(state, proof, url);
  }

  Future<Map<String, dynamic>?> claim(OAuthPairing pending) async {
    final response = await _post('/auth/claim', {
      'state': pending.state,
      'proof': pending.proof,
    });
    return response['pending'] == true ? null : response;
  }

  Future<Map<String, dynamic>> refresh(String handle) =>
      _post('/auth/refresh', {'handle': handle});

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> json,
  ) async {
    if (!configured) throw const CatalogFailure('暂未配置浏览器授权服务。');
    try {
      final response = await http.postUri<Object?>(
        endpoint!.resolve(path),
        data: json,
        options: Options(followRedirects: false),
      );
      if (response.data case final Map<String, dynamic> result) return result;
      throw const CatalogFailure('授权服务返回了不支持的数据。');
    } on DioException catch (error) {
      throw CatalogFailure(
        error.response?.statusCode == 429
            ? '授权请求过于频繁，请稍后再试。'
            : '授权请求失败或已过期，请重新授权。',
      );
    }
  }
}

class BangumiSyncApi {
  BangumiSyncApi(
    this.http, {
    this.interval = const Duration(milliseconds: 190),
  });
  final Dio http;
  final Duration interval;
  DateTime _previous = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _tail = Future.value();

  Future<Object?> request(
    String token,
    String path, {
    String method = 'GET',
    Map<String, Object>? query,
    Map<String, Object>? data,
    bool allowMissing = false,
  }) {
    final result = _tail.then((_) async {
      final wait = interval - DateTime.now().difference(_previous);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _previous = DateTime.now();
      try {
        final response = await http.request<Object?>(
          path,
          data: data,
          queryParameters: query,
          options: Options(
            method: method,
            followRedirects: false,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        return response.data;
      } on DioException catch (error) {
        final code = error.response?.statusCode;
        if (code == 404 && allowMissing) return null;
        throw CatalogFailure(switch (code) {
          401 => 'Bangumi 授权已失效，请重新绑定。',
          403 => '当前 Bangumi 授权没有执行此操作的权限。',
          429 => '已达到 Bangumi 请求限制，本次同步已暂停。',
          _ => 'Bangumi 同步请求未完成，本地数据已保留。',
        });
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<BangumiAccount> me(String token) async {
    final result = await request(token, '/v0/me');
    if (result is! Map ||
        result['username'] is! String ||
        (result['username'] as String).isEmpty) {
      throw const CatalogFailure('无法验证 Bangumi 账号。');
    }
    final username = result['username'] as String;
    return BangumiAccount(username, result['nickname'] as String? ?? username);
  }

  Future<Map<int, Map<String, dynamic>>> collections(
    String token,
    String username,
  ) async {
    final records = <int, Map<String, dynamic>>{};
    const limit = 50;
    for (var offset = 0; offset < 15000;) {
      final value = await request(
        token,
        '/v0/users/${Uri.encodeComponent(username)}/collections',
        query: {'subject_type': 2, 'limit': limit, 'offset': offset},
      );
      if (value is! Map || value['data'] is! List) {
        throw const CatalogFailure('Bangumi 返回的收藏列表不完整。');
      }
      final entries = value['data'] as List;
      for (final item in entries.whereType<Map<String, dynamic>>()) {
        final id = item['subject_id'];
        if (id is int) records[id] = item;
      }
      offset += entries.length;
      final total = value['total'];
      if (entries.isEmpty ||
          (total is int ? offset >= total : entries.length < limit)) {
        return records;
      }
    }
    throw const CatalogFailure('收藏数量超出本次同步范围，已保留当前记录。');
  }

  Future<void> upsertCollection(
    String token,
    int subject, {
    required CollectionStatus status,
    int? rating,
    String? comment,
    bool private = true,
  }) async {
    final trimmed = comment?.trim();
    await request(
      token,
      '/v0/users/-/collections/$subject',
      method: 'POST',
      data: {
        'type': status.code,
        'private': private,
        if (rating != null && rating >= 1 && rating <= 10) 'rate': rating,
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      },
    );
  }

  Future<void> wish(String token, int subject) =>
      upsertCollection(token, subject, status: CollectionStatus.wish);

  Future<int?> episodeState(String token, int episode) async {
    final value = await request(
      token,
      '/v0/users/-/collections/-/episodes/$episode',
      allowMissing: true,
    );
    return value is Map ? value['type'] as int? : null;
  }

  Future<void> markWatched(String token, int episode) async {
    await request(
      token,
      '/v0/users/-/collections/-/episodes/$episode',
      method: 'PUT',
      data: {'type': 2},
    );
  }
}

class BangumiSyncService {
  BangumiSyncService(this.library, this.vault, this.api, this.oauth);
  final LocalLibrary library;
  final CredentialVault vault;
  final BangumiSyncApi api;
  final BangumiOAuthBridge oauth;
  bool _running = false;
  static const _key = 'bangumi.account';
  AppDatabase get _db => library.db;

  Future<BangumiAccount?> account() async {
    final state = await vault.read(_key);
    return state == null
        ? null
        : BangumiAccount(state['username'] as String, state['name'] as String);
  }

  Future<void> unlink() => vault.delete(_key);

  Future<BangumiAccount> bindPersonalToken(String input) =>
      _bind({'access_token': input.trim()});

  Future<BangumiAccount?> complete(OAuthPairing pending) async {
    final response = await oauth.claim(pending);
    return response == null ? null : _bind(response);
  }

  Future<BangumiAccount> _bind(Map<String, dynamic> raw) async {
    final token = raw['access_token'];
    if (token is! String ||
        !RegExp(r'^[a-zA-Z0-9_.~+/=-]{12,1024}$').hasMatch(token)) {
      throw const CatalogFailure('请输入有效的 Bangumi 访问令牌。');
    }
    final validated = await api.me(token);
    final expiry = raw['expires_in'];
    await vault.write(_key, {
      'access_token': token,
      'username': validated.username,
      'name': validated.name,
      if (raw['refresh_handle'] is String)
        'refresh_handle': raw['refresh_handle'],
      if (expiry is num)
        'expires_at':
            DateTime.now().millisecondsSinceEpoch + expiry.toInt() * 1000,
    });
    return validated;
  }

  Future<String> _token(Map<String, dynamic> state) async {
    final expires = state['expires_at'];
    final refresh = state['refresh_handle'];
    if (expires is int &&
        DateTime.now().millisecondsSinceEpoch + 60000 >= expires &&
        refresh is String &&
        oauth.configured) {
      final result = await oauth.refresh(refresh);
      await _bind(result);
      return result['access_token'] as String;
    }
    return state['access_token'] as String;
  }

  Future<String> sync({
    required bool pushFavorites,
    required bool pushWatched,
  }) async {
    if (_running) throw const CatalogFailure('正在同步，请稍候。');
    _running = true;
    var imported = 0;
    var uploaded = 0;
    var watched = 0;
    var conflicts = 0;
    try {
      final credentials = await vault.read(_key);
      if (credentials == null) throw const CatalogFailure('请先绑定 Bangumi 账号。');
      final token = await _token(credentials);
      final username = credentials['username'] as String;
      final remote = await api.collections(token, username);
      final local = await library.watchFavoriteEntries().first;
      final localById = {for (final entry in local) entry.anime.id: entry};
      final tombstones =
          (await (_db.select(
                _db.syncSnapshots,
              )..where((row) => row.key.like('local-remove/%'))).get())
              .map((row) => int.tryParse(row.key.split('/').last))
              .nonNulls
              .toSet();
      for (final entry in remote.entries) {
        if (tombstones.contains(entry.key)) {
          conflicts++;
          continue;
        }
        final remoteStatus = CollectionStatus.fromCode(
          entry.value['type'] as int?,
        );
        final rawRate = (entry.value['rate'] as num?)?.toInt();
        final remoteRating =
            rawRate != null && rawRate >= 1 && rawRate <= 10 ? rawRate : null;
        final rawComment = (entry.value['comment'] as String?)?.trim();
        final remoteComment =
            rawComment == null || rawComment.isEmpty ? null : rawComment;
        final localEntry = localById[entry.key];
        if (localEntry == null) {
          final details = entry.value['subject'];
          if (details is! Map<String, dynamic>) continue;
          final anime = parseBangumiAnime({
            ...details,
            'id': entry.key,
            'type': 2,
          });
          if (anime == null) continue;
          await library.setCollection(
            anime,
            remoteStatus,
            rating: remoteRating,
            comment: remoteComment,
            markDirty: false,
          );
          imported++;
          continue;
        }
        final differs =
            localEntry.status != remoteStatus ||
            localEntry.rating != remoteRating ||
            localEntry.comment != remoteComment;
        if (!localEntry.dirty) {
          if (differs) {
            await library.setCollection(
              localEntry.anime,
              remoteStatus,
              rating: remoteRating,
              comment: remoteComment,
              markDirty: false,
            );
          }
        } else if (!pushFavorites && differs) {
          // Local-first: keep local dirty edits intact and surface conflict count.
          conflicts++;
        }
      }
      if (pushFavorites) {
        for (final entry in local) {
          final id = entry.anime.id;
          if (!remote.containsKey(id)) {
            // Recheck before pushing unless local holds explicit dirty edits.
            final existing = await api.request(
              token,
              '/v0/users/${Uri.encodeComponent(username)}/collections/$id',
              allowMissing: true,
            );
            if (existing is Map<String, dynamic> && !entry.dirty) {
              remote[id] = existing;
              conflicts++;
              continue;
            }
          } else if (!entry.dirty) {
            continue;
          }
          await api.upsertCollection(
            token,
            id,
            status: entry.status,
            rating: entry.rating,
            comment: entry.comment,
            private: true,
          );
          await library.clearFavoriteDirty(id);
          remote[id] = {
            'type': entry.status.code,
            if (entry.rating != null) 'rate': entry.rating,
            if (entry.comment != null) 'comment': entry.comment,
          };
          uploaded++;
        }
      }
      if (pushWatched) {
        final table = _db.watchSessions;
        final rows =
            await (_db.select(table).join([
                  innerJoin(
                    _db.mediaEntries,
                    _db.mediaEntries.id.equalsExp(table.mediaId),
                  ),
                ])..where(
                  table.completed.equals(true) &
                      _db.mediaEntries.episodeId.isNotNull(),
                ))
                .get();
        final seen = <int>{};
        for (final row in rows) {
          final media = row.readTable(_db.mediaEntries);
          final episode = media.episodeId!;
          final collection = remote[media.subjectId];
          if (collection == null ||
              collection['type'] == 5 ||
              !seen.add(episode)) {
            continue;
          }
          final key = 'uploaded/$username/$episode';
          final previous = await (_db.select(
            _db.syncSnapshots,
          )..where((row) => row.key.equals(key))).getSingleOrNull();
          if (previous != null) continue;
          final status = await api.episodeState(token, episode);
          if (status == 3) {
            conflicts++;
            continue;
          }
          if (status != 2) {
            await api.markWatched(token, episode);
            watched++;
          }
          await _log(key, '2');
        }
      }
      final result =
          '导入 $imported 部，新增远端收藏 $uploaded 部，上传看过 $watched 集，保留冲突 $conflicts 项。';
      await _log('sync/last/$username', result);
      return result;
    } on CatalogFailure catch (error) {
      await _log('sync/error', error.message);
      throw CatalogFailure(
        '${error.message} 本次已成功导入 $imported 部、提交收藏 $uploaded 部、提交看过 $watched 集。',
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _log(String key, String value) async {
    await _db
        .into(_db.syncSnapshots)
        .insertOnConflictUpdate(
          SyncSnapshot(
            key: key,
            value: value,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }
}
