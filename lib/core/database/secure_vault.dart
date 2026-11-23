import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialVault {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, Object?> value);
  Future<void> delete(String key);
}

class SecureVault implements CredentialVault {
  const SecureVault();
  static const _storage = FlutterSecureStorage();

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = await _storage.read(key: 'aniview.$key');
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) =>
      _storage.write(key: 'aniview.$key', value: jsonEncode(value));

  @override
  Future<void> delete(String key) => _storage.delete(key: 'aniview.$key');
}

String randomIdentifier([int length = 24]) {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(length, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
