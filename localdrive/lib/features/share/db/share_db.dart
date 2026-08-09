import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../models/share_model.dart';

/// The API surface for both ways content leaves an account: a public link, and
/// a direct grant to another account on this same server.
class ShareDb {
  const ShareDb(this._api);

  final ApiClient _api;

  ShareModel _shareFromJson(Map<String, dynamic> json) =>
      ShareModel.fromJson(json, resolveUrl: _api.publicLink);

  Future<List<ShareModel>> forNode(String nodeId) async {
    final json = await _api.get(Api.nodeShares(nodeId));
    return (json['shares'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_shareFromJson)
        .toList(growable: false);
  }

  Future<List<ShareModel>> mine() async {
    final json = await _api.get(Api.myShares);
    return (json['shares'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_shareFromJson)
        .toList(growable: false);
  }

  Future<ShareModel> create(
    String nodeId, {
    String password = '',
    int expiresAt = 0,
    bool allowDownload = true,
  }) async =>
      _shareFromJson(await _api.post(
        Api.createShare(nodeId),
        idempotencyKey: 'share-${DateTime.now().microsecondsSinceEpoch}',
        body: <String, dynamic>{
          if (password.isNotEmpty) 'password': password,
          if (expiresAt > 0) 'expires_at': expiresAt,
          'allow_download': allowDownload,
        },
      ));

  /// Edits a link in place. The URL never changes, so anyone already holding
  /// it keeps whatever access the new settings allow.
  Future<ShareModel> update(
    String shareId, {
    String? password,
    int? expiresAt,
    bool? allowDownload,
  }) async =>
      _shareFromJson(await _api.patch(
        Api.share(shareId),
        body: <String, dynamic>{
          'password': ?password,
          'expires_at': ?expiresAt,
          'allow_download': ?allowDownload,
        },
      ));

  Future<void> revoke(String shareId) => _api.delete(Api.share(shareId));

  // holding a link, with no session

  /// Resolves a public link. A password protected link answers 401 until the
  /// password is supplied, which is what the prompt on the share screen is
  /// reacting to.
  Future<PublicShareModel> publicShare(
    String token, {
    String password = '',
  }) async =>
      PublicShareModel.fromJson(
        password.isEmpty
            ? await _api.get(Api.publicShare(token))
            : await _api.post(
                Api.publicShare(token),
                body: <String, dynamic>{'password': password},
              ),
      );

  /// The absolute bytes URL for a link. No auth headers belong on this one.
  String publicDownloadUrl(String token) =>
      _api.absolute(Api.publicShareDownload(token));

  // account to account

  Future<List<GrantModel>> grants(String nodeId) async {
    final json = await _api.get(Api.permissions(nodeId));
    return (json['people'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(GrantModel.fromJson)
        .toList(growable: false);
  }

  Future<GrantModel> grant(String nodeId, String userId, String role) async =>
      GrantModel.fromJson(await _api.post(
        Api.permissions(nodeId),
        body: <String, dynamic>{'user_id': userId, 'role': role},
      ));

  Future<void> revokeGrant(String nodeId, String userId) =>
      _api.delete(Api.permission(nodeId, userId));

  /// Every account on this server, name and avatar seed only. This is what
  /// makes the People picker a row of faces rather than a text field.
  Future<List<PersonModel>> people({String query = ''}) async {
    final json = await _api.get(
      Api.users,
      query: <String, dynamic>{if (query.isNotEmpty) 'q': query},
    );
    return (json['users'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PersonModel.fromJson)
        .toList(growable: false);
  }
}
