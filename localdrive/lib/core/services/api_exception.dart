/// Why a request failed, classified once at the transport boundary so no
/// widget ever inspects a status code or a Dio error type.
enum ApiErrorKind {
  /// the device has no connection at all
  offline,

  /// the device is online but this node did not answer
  unreachable,

  timeout,
  unauthorized,
  forbidden,
  devicePending,
  mustChangePassword,
  notFound,
  conflict,
  invalidRequest,
  quota,
  rateLimited,
  libraryOffline,
  shareExpired,
  sharePasswordRequired,
  sharePasswordWrong,
  server,
  cancelled,
  unknown;

  /// whether retrying could plausibly succeed on its own
  bool get isTransient => switch (this) {
        ApiErrorKind.offline ||
        ApiErrorKind.unreachable ||
        ApiErrorKind.timeout ||
        ApiErrorKind.rateLimited ||
        ApiErrorKind.server =>
          true,
        _ => false,
      };

  /// whether this failure means the device could not reach the server at all,
  /// as opposed to reaching it and being told no. Only these justify falling
  /// back to what this device already has cached
  bool get isConnectivity => switch (this) {
        ApiErrorKind.offline ||
        ApiErrorKind.unreachable ||
        ApiErrorKind.timeout =>
          true,
        _ => false,
      };
}

/// One failed API call, carrying enough to render a specific message and to
/// decide whether the transfer queue should keep retrying.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.field,
  });

  final ApiErrorKind kind;

  /// the server's own plain sentence, already written for a person to read
  final String message;

  /// the machine readable code from the error envelope
  final String? code;
  final int? statusCode;
  final String? field;

  /// Maps the server's error envelope onto a kind. The server writes one
  /// envelope for every endpoint, so this switch is the whole mapping.
  static ApiErrorKind kindFromCode(String? code, int? status) {
    return switch (code) {
      'unauthorized' || 'session_invalid' || 'bad_credentials' =>
        ApiErrorKind.unauthorized,
      'device_pending' => ApiErrorKind.devicePending,
      'must_change_password' => ApiErrorKind.mustChangePassword,
      'forbidden' => ApiErrorKind.forbidden,
      'not_found' => ApiErrorKind.notFound,
      'quota_exceeded' => ApiErrorKind.quota,
      'rate_limited' => ApiErrorKind.rateLimited,
      'library_offline' => ApiErrorKind.libraryOffline,
      'share_expired' => ApiErrorKind.shareExpired,
      'share_password_required' => ApiErrorKind.sharePasswordRequired,
      'share_password_wrong' => ApiErrorKind.sharePasswordWrong,
      'invalid_request' ||
      'invalid_json' ||
      'invite_invalid' ||
      'confirmation_required' =>
        ApiErrorKind.invalidRequest,
      'setup_done' ||
      'setup_required' ||
      'username_taken' ||
      'email_taken' ||
      'already_registered' ||
      'in_trash' =>
        ApiErrorKind.conflict,
      _ => _fromStatus(status),
    };
  }

  static ApiErrorKind _fromStatus(int? status) {
    if (status == null) return ApiErrorKind.unknown;
    if (status >= 500) return ApiErrorKind.server;
    return switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      410 => ApiErrorKind.shareExpired,
      429 => ApiErrorKind.rateLimited,
      507 => ApiErrorKind.quota,
      _ => ApiErrorKind.unknown,
    };
  }

  bool get isTransient => kind.isTransient;

  @override
  String toString() => 'ApiException($kind, $code): $message';
}
