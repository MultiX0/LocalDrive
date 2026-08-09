import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/storage_keys.dart';
import '../db/local_db.dart';
import '../theme/ld_theme.dart';
import 'api_client.dart';
import 'platform_service.dart';
import 'secure_store_service.dart';
import 'websocket_service.dart';

/// Secure storage and preferences. Overridden in tests with a fake.
final secureStoreProvider = Provider<SecureStoreService>((ref) {
  return SecureStoreService();
});

/// The one channel to native code, for the work Flutter cannot do itself.
final platformServiceProvider = Provider<PlatformService>((ref) {
  final service = PlatformService()..start();
  ref.onDispose(service.dispose);
  return service;
});

/// The device database: the metadata cache, the offline registry, and the
/// durable transfer queue. One instance for the life of the app, closed when
/// the container is disposed. Overridden in tests with an in memory executor.
final localDbProvider = Provider<LocalDb>((ref) {
  final db = LocalDb();
  ref.onDispose(db.close);
  return db;
});

/// The one HTTP client. Everything else reaches the server through a feature
/// db class that takes this.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(store: ref.watch(secureStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// The one websocket. It is connected by the session controller once there is
/// a node and a token, and disconnected on sign out.
final webSocketProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Live connection state, which the offline banner and the transfer queue both
/// watch.
final connectionStateProvider = StreamProvider<LdConnectionState>((ref) {
  final service = ref.watch(webSocketProvider);
  return service.connection;
});

/// Whether the device itself has a network at all. The queue pauses cleanly on
/// this rather than letting every in-flight item discover it separately.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  Future<bool> hasNetwork(List<ConnectivityResult> results) async =>
      results.any((r) => r != ConnectivityResult.none);

  final controller = StreamController<bool>();
  StreamSubscription<List<ConnectivityResult>>? subscription;

  Future<void> start() async {
    final initial = await connectivity.checkConnectivity();
    if (!controller.isClosed) controller.add(await hasNetwork(initial));
    subscription = connectivity.onConnectivityChanged.listen((results) async {
      if (!controller.isClosed) controller.add(await hasNetwork(results));
    });
  }

  unawaited(start());
  ref.onDispose(() {
    subscription?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Every live event, for the small widgets that react to one type.
final eventStreamProvider = StreamProvider<LdEvent>((ref) {
  return ref.watch(webSocketProvider).events;
});

/// Fires after a reconnect, which is the cue to refetch rather than trust the
/// cache for anything missed while the socket was down.
final reconnectedProvider = StreamProvider<void>((ref) {
  return ref.watch(webSocketProvider).onReconnected;
});

/// The chosen locale. Null means follow the system.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    final saved =
        await ref.read(secureStoreProvider).readString(StorageKeys.localeCode);
    if (saved != null && saved.isNotEmpty) state = Locale(saved);
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(secureStoreProvider)
        .writeString(StorageKeys.localeCode, locale.languageCode);
  }

  Future<void> followSystem() async {
    state = null;
    await ref.read(secureStoreProvider).remove(StorageKeys.localeCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// The theme, composed from the current locale so the Latin and Arabic
/// typefaces swap at the ThemeData level rather than per widget.
final themeProvider = Provider((ref) {
  final locale = ref.watch(localeProvider) ?? const Locale('en');
  return LdTheme.forLocale(locale);
});
