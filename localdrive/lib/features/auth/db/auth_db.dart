import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../models/user_model.dart';

/// What a login attempt came back with: real tokens, or a device held for
/// approval with only a narrow token to poll with.
class AuthResult {
  const AuthResult({
    required this.pending,
    this.accessToken = '',
    this.refreshToken = '',
    this.sessionId = '',
    this.user,
  });

  final bool pending;
  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final UserModel? user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthResult(
      pending: json['status'] == 'pending',
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      user: userJson is Map<String, dynamic>
          ? UserModel.fromJson(userJson)
          : null,
    );
  }
}

/// The API surface for accounts and sessions.
class AuthDb {
  const AuthDb(this._api);

  final ApiClient _api;

  Future<ServerStatusModel> status() async =>
      ServerStatusModel.fromJson(await _api.get(Api.status));

  Future<AuthResult> setup({
    required String username,
    required String password,
    required String serverName,
    required String deviceName,
    required String platform,
    String email = '',
  }) async =>
      AuthResult.fromJson(await _api.post(Api.setup, body: <String, dynamic>{
        'username': username,
        'password': password,
        'server_name': serverName,
        'device_name': deviceName,
        'platform': platform,
        if (email.isNotEmpty) 'email': email,
      }));

  Future<AuthResult> register({
    required String username,
    required String password,
    required String inviteCode,
    required String deviceName,
    required String platform,
    String email = '',
  }) async =>
      AuthResult.fromJson(await _api.post(Api.register, body: <String, dynamic>{
        'username': username,
        'password': password,
        'invite_code': inviteCode,
        'device_name': deviceName,
        'platform': platform,
        if (email.isNotEmpty) 'email': email,
      }));

  Future<AuthResult> login({
    required String username,
    required String password,
    required String deviceName,
    required String platform,
    String totpCode = '',
  }) async =>
      AuthResult.fromJson(await _api.post(Api.login, body: <String, dynamic>{
        'username': username,
        'password': password,
        'device_name': deviceName,
        'platform': platform,
        if (totpCode.isNotEmpty) 'totp_code': totpCode,
      }));

  /// Polls a pending device. Returns the tokens the moment it is approved.
  Future<({String status, AuthResult? tokens})> sessionStatus(
    String sessionId,
  ) async {
    final json = await _api.get(Api.sessionStatus(sessionId));
    final status = json['status'] as String? ?? '';
    if (json.containsKey('access_token')) {
      return (status: status, tokens: AuthResult.fromJson(json));
    }
    return (status: status, tokens: null);
  }

  Future<void> logout() => _api.post(Api.logout);

  Future<UserModel> me() async => UserModel.fromJson(await _api.get(Api.me));

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.patch(Api.mePassword, body: <String, dynamic>{
        'current_password': currentPassword,
        'new_password': newPassword,
      });

  Future<UserModel> updateProfile(String displayName) async =>
      UserModel.fromJson(await _api.patch(
        Api.meProfile,
        body: <String, dynamic>{'display_name': displayName},
      ));

  Future<({String label, int expiresAt})> checkInvite(String code) async {
    final json = await _api.get(Api.checkInvite(code));
    return (
      label: json['label'] as String? ?? '',
      expiresAt: json['expires_at'] as int? ?? 0,
    );
  }

  // devices and sessions

  Future<List<SessionModel>> sessions() async {
    final json = await _api.get(Api.sessions);
    final list = json['sessions'] as List<dynamic>? ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SessionModel.fromJson)
        .toList(growable: false);
  }

  Future<List<SessionModel>> pendingDevices({bool adminWide = false}) async {
    final json =
        await _api.get(adminWide ? Api.adminPendingDevices : Api.pendingDevices);
    final list = json['devices'] as List<dynamic>? ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SessionModel.fromJson)
        .toList(growable: false);
  }

  Future<void> approveDevice(String sessionId) =>
      _api.post(Api.approveDevice(sessionId));

  Future<void> denyDevice(String sessionId) =>
      _api.post(Api.denyDevice(sessionId));

  Future<void> revokeSession(String sessionId) =>
      _api.delete(Api.session(sessionId));

  // two factor

  Future<({String secret, String otpauthUrl, List<String> recoveryCodes})>
      beginTotp() async {
    final json = await _api.post(Api.totpBegin);
    final codes = (json['recovery_codes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
    return (
      secret: json['secret'] as String? ?? '',
      otpauthUrl: json['otpauth_url'] as String? ?? '',
      recoveryCodes: codes,
    );
  }

  Future<void> confirmTotp(String code) =>
      _api.post(Api.totpVerify, body: <String, dynamic>{'code': code});

  Future<void> disableTotp(String password) =>
      _api.post(Api.totpDisable, body: <String, dynamic>{'password': password});
}
