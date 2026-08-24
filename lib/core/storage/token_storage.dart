import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_storage.g.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'bloom_app_access_token';
  static const _systemIdKey = 'bloom_system_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<int?> readSystemId() async {
    final raw = await _storage.read(key: _systemIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveSession({required String token, required int systemId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _systemIdKey, value: systemId.toString());
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _systemIdKey);
  }
}

@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage(ref.watch(secureStorageProvider));
