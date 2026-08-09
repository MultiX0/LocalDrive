import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_endpoints.dart';
import '../constants/storage_keys.dart';

/// One live change event from the server.
class LdEvent {
  const LdEvent({required this.type, required this.at, required this.payload});

  final String type;
  final int at;
  final Map<String, dynamic> payload;

  factory LdEvent.fromJson(Map<String, dynamic> json) => LdEvent(
        type: json['type'] as String? ?? '',
        at: json['at'] as int? ?? 0,
        payload: (json['payload'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      );

  String? get nodeId => payload['id'] as String? ?? payload['node_id'] as String?;
  String? get parentId => payload['parent_id'] as String?;
}

/// Whether the app currently has a live connection to its node.
enum LdConnectionState { disconnected, connecting, connected }

/// The single websocket connection. One per active client, reconnecting with
/// backoff, and it tells listeners when it comes back so they can do the
/// reconciliation fetch for anything missed while offline.
class WebSocketService {
  WebSocketService();

  final StreamController<LdEvent> _events = StreamController<LdEvent>.broadcast();
  final StreamController<LdConnectionState> _state =
      StreamController<LdConnectionState>.broadcast();

  /// fires after a reconnect, which is the cue to refetch rather than trust
  /// the cache
  final StreamController<void> _reconnected = StreamController<void>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _wanted = false;
  bool _hadConnection = false;
  String? _baseUrl;
  String? _token;
  LdConnectionState _current = LdConnectionState.disconnected;

  Stream<LdEvent> get events => _events.stream;
  Stream<LdConnectionState> get connection => _state.stream;
  Stream<void> get onReconnected => _reconnected.stream;
  LdConnectionState get currentState => _current;

  /// Events of one type only, which is what a small badge widget watches
  /// rather than every event on the socket.
  Stream<LdEvent> ofTypes(Set<String> types) =>
      _events.stream.where((event) => types.contains(event.type));

  void connect({required String baseUrl, required String token}) {
    _baseUrl = baseUrl;
    _token = token;
    _wanted = true;
    _attempt = 0;
    _open();
  }

  void disconnect() {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();
    _emitState(LdConnectionState.disconnected);
  }

  void _open() {
    if (!_wanted || _baseUrl == null || _token == null) return;
    _closeChannel();
    _emitState(LdConnectionState.connecting);

    final uri = _socketUri(_baseUrl!, _token!);
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onClosed,
        onError: (Object _) => _onClosed(),
        cancelOnError: true,
      );
      unawaited(
        channel.ready.then<void>((_) {
          if (!_wanted) return;
          _attempt = 0;
          _emitState(LdConnectionState.connected);
          if (_hadConnection) _reconnected.add(null);
          _hadConnection = true;
        }).catchError((Object _) {
          _onClosed();
        }),
      );
    } on Object {
      _onClosed();
    }
  }

  /// The token goes in the query string because a browser cannot set a header
  /// on a websocket handshake, and the native clients then use the same path.
  static Uri _socketUri(String baseUrl, String token) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: Api.websocket,
      queryParameters: <String, String>{'access_token': token},
    );
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _events.add(LdEvent.fromJson(decoded));
      }
    } on FormatException {
      // a malformed frame is not worth tearing the connection down for
    }
  }

  void _onClosed() {
    _closeChannel();
    if (!_wanted) {
      _emitState(LdConnectionState.disconnected);
      return;
    }
    _emitState(LdConnectionState.disconnected);
    _scheduleReconnect();
  }

  /// Exponential backoff with jitter, capped, so a node that is down does not
  /// get hammered and a phone does not burn battery retrying.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _attempt = math.min(_attempt + 1, 10);
    final base = AppDurations.reconnectMin.inMilliseconds * (1 << (_attempt - 1));
    final capped = math.min(base, AppDurations.reconnectMax.inMilliseconds);
    final jitter = math.Random().nextInt(math.max(1, capped ~/ 4));
    _reconnectTimer = Timer(
      Duration(milliseconds: capped + jitter),
      _open,
    );
  }

  void _closeChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _emitState(LdConnectionState next) {
    if (_current == next) return;
    _current = next;
    if (!_state.isClosed) _state.add(next);
  }

  /// Called after a token refresh so the socket reconnects with the new one.
  void updateToken(String token) {
    _token = token;
    if (_wanted) _open();
  }

  void dispose() {
    disconnect();
    _events.close();
    _state.close();
    _reconnected.close();
  }
}
