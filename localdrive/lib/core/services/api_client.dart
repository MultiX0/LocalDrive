import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../constants/api_endpoints.dart';
import '../constants/storage_keys.dart';
import 'api_exception.dart';
import 'secure_store_service.dart';

/// The one place an HTTP request leaves the app. Every feature's db class goes
/// through here; nothing else imports dio.
///
/// It owns three things nobody else should have to think about: attaching the
/// bearer token, refreshing it exactly once when it expires and replaying the
/// request, and turning every failure into an ApiException with a kind.
class ApiClient {
  ApiClient({required this._store, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = AppDurations.connectTimeout
      ..receiveTimeout = AppDurations.requestTimeout
      // a browser's fetch has no send timeout to set, and dio warns loudly on
      // every request if one is configured anyway
      ..sendTimeout = kIsWeb ? null : AppDurations.requestTimeout
      ..headers = <String, dynamic>{'Accept': 'application/json'}
      // this client validates status itself so a 4xx is an exception with a
      // parsed envelope rather than a silent response
      ..validateStatus = (status) => status != null && status < 400;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  final SecureStoreService _store;

  String? _baseUrl;
  String? _accessToken;
  Completer<bool>? _refreshInFlight;

  /// Fired when the session is gone for good, so the router can send the
  /// person back to sign in. Never fired for a token that merely expired.
  final StreamController<void> _sessionLost = StreamController<void>.broadcast();

  Stream<void> get onSessionLost => _sessionLost.stream;

  String? get baseUrl => _baseUrl;
  bool get hasNode => _baseUrl != null && _baseUrl!.isNotEmpty;
  String? get accessToken => _accessToken;

  /// Points this client at a node. Called by onboarding and by Switch Node.
  void useNode(String url) {
    _baseUrl = normalizeNodeUrl(url);
    _dio.options.baseUrl = _baseUrl!;
  }

  void useTokens({required String? accessToken}) {
    _accessToken = accessToken;
  }

  /// Restores the node and tokens from secure storage on a cold start.
  Future<bool> restore() async {
    var url = await _store.readNodeUrl();
    if (url == null || url.isEmpty) {
      // In a browser the app was served by a server, and asking someone to
      // type the address of the machine they are already talking to is
      // nonsense. It also loses invite links: /invite/CODE on a device with no
      // node configured is bounced to onboarding and the code goes with it.
      final sameOrigin = await _originIsAServer();
      if (sameOrigin == null) return false;
      url = sameOrigin;
      await _store.writeNodeUrl(url);
    }
    useNode(url);
    _accessToken = await _store.readAccessToken();
    return _accessToken != null;
  }

  /// The origin this page came from, if a Local Drive server answers there.
  ///
  /// Checked rather than assumed. During development the app is often served
  /// from one port and the server listens on another, and adopting an origin
  /// with nothing behind it would replace "which server?" with a connection
  /// error, which is worse.
  Future<String?> _originIsAServer() async {
    if (!kIsWeb) return null;
    final origin = Uri.base.origin;
    if (origin.isEmpty || origin.startsWith('file:')) return null;
    try {
      final probe = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await probe.getUri<Map<String, dynamic>>(
        Uri.parse('$origin${Api.status}'),
      );
      // any json with a server_id is this application, not somebody else's 200
      return response.data?['server_id'] is String ? origin : null;
    } on Object {
      return null;
    }
  }

  Future<void> clearSession() async {
    _accessToken = null;
    await _store.clearTokens();
  }

  /// Trims and normalizes whatever someone typed into the address field.
  ///
  /// Self hosted means an address on a network far more often than a domain,
  /// so "192.168.1.5" has to work with nothing else typed. A bare address gets
  /// the app's own port and a scheme guessed from the address itself;
  /// anything explicit is left exactly as typed.
  static String normalizeNodeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;

    final hadScheme =
        value.startsWith('http://') || value.startsWith('https://');
    if (!hadScheme) {
      value = '${_schemeFor(value)}://$value';
    }

    Uri parsed;
    try {
      parsed = Uri.parse(value);
    } on FormatException {
      return value;
    }

    // typing a bare address means "my Local Drive server", so it gets the
    // port Local Drive serves on. typing a full url means exactly that url,
    // so its scheme's own default port is left alone.
    if (!parsed.hasPort && !hadScheme) {
      parsed = parsed.replace(port: defaultPort);
    }

    return parsed
        .replace(path: parsed.path.replaceAll(RegExp(r'/+$'), ''))
        .toString();
  }

  // Picks the scheme for an address someone typed without one.
  //
  // Self hosted almost always means an ip or a name on the local network, and
  // no certificate authority issues certificates for either, so those get
  // http. A name that looks like a public domain is the one case where a real
  // certificate is both available and expected, so that gets https. Anyone
  // whose setup does not match either guess can type the scheme.
  static String _schemeFor(String host) {
    final name = host.split('/').first.split(':').first;
    if (name.isEmpty) return 'http';

    final isIPv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(name);
    final isIPv6 = name.contains(':') || name.startsWith('[');
    if (isIPv4 || isIPv6) return 'http';

    // "nas", "nas.local" and "nas.lan" are all names that only resolve on this
    // network, so none of them can have a public certificate
    final lower = name.toLowerCase();
    if (!lower.contains('.') ||
        lower.endsWith('.local') ||
        lower.endsWith('.lan') ||
        lower.endsWith('.home') ||
        lower.endsWith('.internal')) {
      return 'http';
    }
    return 'https';
  }

  /// The one port a Local Drive server serves on, matching the backend's own
  /// default. Not 443, so it does not collide with whatever else is on the
  /// machine someone is hosting from.
  static const int defaultPort = 7443;

  /// Builds an absolute URL for something an image or a video widget will
  /// fetch itself, such as a thumbnail.
  ///
  /// [signed] puts the access token in the query string. A media element
  /// fetches its own URL and there is no hook to add a header to it, so a
  /// private thumbnail has no other way to say who is asking. It stays off by
  /// default because a public share link is meant to work without an account
  /// and must never carry one: that link gets copied and pasted to people.
  String absolute(String path, {bool signed = false}) {
    final url = '${_baseUrl ?? ''}$path';
    final token = _accessToken;
    if (!signed || token == null || token.isEmpty) return url;
    return '$url${path.contains('?') ? '&' : '?'}'
        'access_token=${Uri.encodeComponent(token)}';
  }

  /// Turns a share or invite link from the server into something that can
  /// actually be opened. Most self-hosted servers have no domain, so they
  /// send a bare path and leave the address to whichever client asks -- this
  /// fills in the one this app is connected to. A link that already has a
  /// scheme (server has a domain configured) is left alone.
  String publicLink(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return absolute(raw);
  }

  Map<String, String> get authHeaders => <String, String>{
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // the verbs

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
    );
    return response ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
        options: idempotencyKey == null
            ? null
            : Options(
                headers: <String, dynamic>{
                  Api.headerIdempotency: idempotencyKey,
                },
              ),
      ),
    );
    return response ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.patch<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      ),
    );
    return response ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.delete<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      ),
    );
    return response ?? const <String, dynamic>{};
  }

  /// A raw request, for the streaming paths that do not want a decoded map.
  Future<Response<T>> raw<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.request<T>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          method: method,
          headers: headers,
          responseType: responseType,
        ),
      );
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<T?> _send<T>(Future<Response<T>> Function() run) async {
    try {
      final response = await run();
      return response.data;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;

    // an expired access token is refreshed once and the request replayed; a
    // refresh that itself fails means the session is genuinely gone
    final refreshable = status == 401 &&
        path != Api.refresh &&
        path != Api.login &&
        error.requestOptions.extra['ld.retried'] != true;

    if (!refreshable) {
      handler.next(error);
      return;
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      _sessionLost.add(null);
      handler.next(error);
      return;
    }

    try {
      final options = error.requestOptions;
      options.extra['ld.retried'] = true;
      options.headers['Authorization'] = 'Bearer $_accessToken';
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Only one refresh runs at a time; every request that hit a 401 together
  /// waits on the same result rather than each rotating the token.
  Future<bool> _refreshOnce() {
    final existing = _refreshInFlight;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;

    Future<void>(() async {
      try {
        final refreshToken = await _store.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          completer.complete(false);
          return;
        }
        final response = await Dio(
          BaseOptions(
            baseUrl: _baseUrl ?? '',
            connectTimeout: AppDurations.connectTimeout,
            receiveTimeout: AppDurations.requestTimeout,
          ),
        ).post<Map<String, dynamic>>(
          Api.refresh,
          data: <String, dynamic>{'refresh_token': refreshToken},
        );
        final data = response.data ?? const <String, dynamic>{};
        final access = data['access_token'] as String?;
        if (access == null || access.isEmpty) {
          completer.complete(false);
          return;
        }
        _accessToken = access;
        await _store.writeTokens(
          accessToken: access,
          refreshToken: data['refresh_token'] as String?,
          sessionId: data['session_id'] as String?,
        );
        completer.complete(true);
      } on DioException {
        completer.complete(false);
      } finally {
        _refreshInFlight = null;
      }
    });

    return completer.future;
  }

  /// Turns a transport failure into something a widget can render. The
  /// server's own message is preferred because it is already a plain sentence
  /// written for a person.
  ApiException _translate(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ApiException(
        kind: ApiErrorKind.cancelled,
        message: 'cancelled',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        kind: ApiErrorKind.timeout,
        message: error.message ?? 'the server took too long to answer',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return ApiException(
        kind: ApiErrorKind.unreachable,
        message: error.message ?? 'could not reach this server',
      );
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? code;
    String? message;
    String? field;

    if (data is Map<String, dynamic>) {
      final envelope = data['error'];
      if (envelope is Map<String, dynamic>) {
        code = envelope['code'] as String?;
        message = envelope['message'] as String?;
        field = envelope['field'] as String?;
      }
    }

    return ApiException(
      kind: ApiException.kindFromCode(code, status),
      message: message ?? 'the server refused that request',
      code: code,
      statusCode: status,
      field: field,
    );
  }

  void dispose() {
    _sessionLost.close();
    _dio.close(force: true);
  }
}
