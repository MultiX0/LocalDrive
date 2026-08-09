import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// The one channel to native code.
///
/// Everything behind it is work Flutter genuinely cannot do on its own:
/// keeping a process alive while the app is off screen, and catching a link
/// that arrives while the app is already running. Anything that could be done
/// in Dart is done in Dart, because a native implementation is a second thing
/// to keep correct on four platforms.
class PlatformService {
  PlatformService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'app.localdrive/platform';

  final MethodChannel _channel;

  final StreamController<String> _deepLinks =
      StreamController<String>.broadcast();

  /// Links that arrived while the app was already open. A cold start link is
  /// handled by the router's own initial location, not here.
  Stream<String> get deepLinks => _deepLinks.stream;

  bool _listening = false;

  /// Only Android has a foreground service to run. iOS keeps background work
  /// alive through a background `URLSession` instead, and desktop has no such
  /// restriction to work around at all.
  static bool get hasBackgroundService =>
      !kIsWeb && Platform.isAndroid;

  void start() {
    if (_listening || kIsWeb) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        final link = call.arguments as String?;
        if (link != null && link.isNotEmpty) _deepLinks.add(link);
      }
      return null;
    });
  }

  Future<void> dispose() async {
    if (_listening) _channel.setMethodCallHandler(null);
    await _deepLinks.close();
  }

  /// Declares to the OS that transfers are genuinely in progress, so the
  /// process is not killed the moment the app leaves the screen.
  Future<void> beginTransfers({
    required String title,
    required String body,
  }) =>
      _invoke('startTransferService', <String, dynamic>{
        'title': title,
        'body': body,
      });

  Future<void> updateTransfers({
    required String title,
    required String body,
    required int percent,
    bool indeterminate = false,
  }) =>
      _invoke('updateTransferProgress', <String, dynamic>{
        'title': title,
        'body': body,
        'progress': percent.clamp(0, 100),
        'indeterminate': indeterminate,
      });

  Future<void> endTransfers() => _invoke('stopTransferService');

  /// Announces "this person, on this network, right now" over the platform's
  /// own service discovery, for as long as a sharing screen is open.
  ///
  /// Presence only. The share itself is still a permission grant against the
  /// server, so the person on the other end gets an ongoing shared item rather
  /// than a one-off copy beamed between two devices.
  Future<void> startPresence({
    required String name,
    required String userId,
    required String avatarSeed,
  }) =>
      _invokeAlways('startPresence', <String, dynamic>{
        'name': name,
        'userId': userId,
        'avatarSeed': avatarSeed,
      });

  Future<void> stopPresence() => _invokeAlways('stopPresence');

  /// Asks the OS to wake the app once there is a network again, so a transfer
  /// that failed offline resumes without anyone reopening the app.
  Future<void> scheduleRetryOnReconnect() => _invoke('scheduleRetry');

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    if (!hasBackgroundService) return;
    await _invokeAlways(method, arguments);
  }

  /// For the calls every native platform answers, unlike the transfer service
  /// which only Android has.
  Future<void> _invokeAlways(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // a missing notification permission, or an OEM that refuses the service.
      // The transfer itself is unaffected: it simply does not survive the app
      // being backgrounded, which is the same as not having asked
    } on MissingPluginException {
      // running against a build of the host app without the channel, which is
      // every test and every platform that has nothing to do here
    }
  }
}
