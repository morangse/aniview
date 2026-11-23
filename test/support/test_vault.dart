import 'package:aniview/core/database/secure_vault.dart';

class TestVault implements CredentialVault {
  final values = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    values[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
