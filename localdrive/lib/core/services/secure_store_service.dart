import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

/// Tokens live in the platform keystore, never in plain preferences.
/// Everything that is only a preference lives in SharedPreferences, so the
/// two are not confused.
class SecureStoreService {
  SecureStoreService({FlutterSecureStorage? secure, this._prefs})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  // tokens and the node address

  Future<String?> readAccessToken() =>
      _secure.read(key: StorageKeys.accessToken);

  Future<String?> readRefreshToken() =>
      _secure.read(key: StorageKeys.refreshToken);

  Future<String?> readSessionId() => _secure.read(key: StorageKeys.sessionId);

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    String? sessionId,
  }) async {
    await _secure.write(key: StorageKeys.accessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secure.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      await _secure.write(key: StorageKeys.sessionId, value: sessionId);
    }
  }

  Future<void> clearTokens() async {
    await _secure.delete(key: StorageKeys.accessToken);
    await _secure.delete(key: StorageKeys.refreshToken);
    await _secure.delete(key: StorageKeys.sessionId);
  }

  Future<String?> readNodeUrl() => _secure.read(key: StorageKeys.nodeUrl);

  Future<void> writeNodeUrl(String url) =>
      _secure.write(key: StorageKeys.nodeUrl, value: url);

  Future<void> clearNodeUrl() => _secure.delete(key: StorageKeys.nodeUrl);

  /// Every node this device has connected to, so Switch Node can offer them
  /// again without a rescan.
  Future<List<KnownNode>> readKnownNodes() async {
    final raw = await _secure.read(key: StorageKeys.knownNodes);
    if (raw == null || raw.isEmpty) return const <KnownNode>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <KnownNode>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(KnownNode.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const <KnownNode>[];
    }
  }

  Future<void> rememberNode(KnownNode node) async {
    final existing = await readKnownNodes();
    final next = <KnownNode>[
      node,
      ...existing.where((n) => n.url != node.url),
    ].take(10).toList(growable: false);
    await _secure.write(
      key: StorageKeys.knownNodes,
      value: jsonEncode(next.map((n) => n.toJson()).toList()),
    );
  }

  Future<void> forgetNode(String url) async {
    final remaining = (await readKnownNodes())
        .where((n) => n.url != url)
        .toList();
    await _secure.write(
      key: StorageKeys.knownNodes,
      value: jsonEncode(remaining.map((n) => n.toJson()).toList()),
    );
  }

  // plain preferences

  Future<String?> readString(String key) async =>
      (await _preferences).getString(key);

  Future<void> writeString(String key, String value) async =>
      (await _preferences).setString(key, value);

  Future<bool> readBool(String key, {bool fallback = false}) async =>
      (await _preferences).getBool(key) ?? fallback;

  Future<void> writeBool(String key, bool value) async =>
      (await _preferences).setBool(key, value);

  Future<int> readInt(String key, {int fallback = 0}) async =>
      (await _preferences).getInt(key) ?? fallback;

  Future<void> writeInt(String key, int value) async =>
      (await _preferences).setInt(key, value);

  Future<void> remove(String key) async => (await _preferences).remove(key);
}

/// A node this device has connected to before.
class KnownNode {
  const KnownNode({
    required this.url,
    required this.name,
    this.serverId = '',
    this.username = '',
    this.lastUsedAt = 0,
  });

  final String url;
  final String name;
  final String serverId;
  final String username;
  final int lastUsedAt;

  factory KnownNode.fromJson(Map<String, dynamic> json) => KnownNode(
    url: json['url'] as String? ?? '',
    name: json['name'] as String? ?? '',
    serverId: json['server_id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    lastUsedAt: json['last_used_at'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'name': name,
    'server_id': serverId,
    'username': username,
    'last_used_at': lastUsedAt,
  };
}
