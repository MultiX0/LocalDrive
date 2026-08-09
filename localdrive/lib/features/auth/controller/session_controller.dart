import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline/controller/offline_controller.dart';
import '../../files/controller/files_controller.dart';
import '../../files/providers/files_providers.dart';
import '../../storage/providers/storage_providers.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_exception.dart';
import '../../../core/services/core_providers.dart';
import '../../../core/services/device_info_service.dart';
import '../../../core/services/secure_store_service.dart';
import '../db/auth_db.dart';
import '../models/user_model.dart';
import 'session_state.dart';

/// The one authority on whether the app is connected, signed in, waiting for
/// approval, or blocked on a temporary password. Everything else, including
/// the router, reads this rather than deciding for itself.
class SessionController extends Notifier<SessionState> {
  Timer? _approvalPoll;
  StreamSubscription<void>? _sessionLost;

  ApiClient get _api => ref.read(apiClientProvider);
  AuthDb get _db => AuthDb(_api);
  SecureStoreService get _store => ref.read(secureStoreProvider);

  @override
  SessionState build() {
    _sessionLost ??= _api.onSessionLost.listen((_) => _handleSessionLost());
    ref.onDispose(() {
      _approvalPoll?.cancel();
      _sessionLost?.cancel();
    });
    unawaited(restore());
    return const SessionState();
  }

  /// Cold start: pick the node and tokens back up, or fall back to onboarding.
  Future<void> restore() async {
    final hadToken = await _api.restore();
    final nodeUrl = _api.baseUrl ?? '';

    if (nodeUrl.isEmpty) {
      state = const SessionState(stage: SessionStage.noNode);
      return;
    }

    ServerStatusModel? status;
    try {
      status = await _db.status();
    } on ApiException {
      // the node is unreachable right now; keep the session so the app opens
      // into its cached view rather than throwing the person back to setup
      status = null;
    }

    if (!hadToken) {
      // no token and no answer. This is the one combination with no way out on
      // its own: there is no cache to fall back into and nothing to sign in
      // to, so leaving the person on a sign-in form for a server that no
      // longer exists is a dead end. Every other path below still opens the
      // app.
      if (status == null && await _nodeIsGone()) {
        await _store.clearNodeUrl();
        state = const SessionState(stage: SessionStage.noNode);
        return;
      }
      state = SessionState(
        stage: SessionStage.signedOut,
        nodeUrl: nodeUrl,
        serverStatus: status,
      );
      return;
    }

    try {
      final user = await _db.me();
      _afterSignIn(user, nodeUrl, status);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        await _api.clearSession();
        state = SessionState(
          stage: SessionStage.signedOut,
          nodeUrl: nodeUrl,
          serverStatus: status,
        );
        return;
      }
      // offline with a stored token: let the app open, the cache will serve
      state = SessionState(
        stage: SessionStage.ready,
        nodeUrl: nodeUrl,
        serverStatus: status,
        error: error,
      );
    }
  }

  /// Points the app at a node without signing in. Onboarding calls this once
  /// someone picks a discovered server or types an address.
  Future<ServerStatusModel> connectTo(String rawUrl) async {
    final url = ApiClient.normalizeNodeUrl(rawUrl);
    _api.useNode(url);
    final status = await _db.status();
    await _store.writeNodeUrl(url);
    await _store.rememberNode(
      KnownNode(
        url: url,
        name: status.name,
        serverId: status.serverId,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    state = state.copyWith(
      stage: SessionStage.signedOut,
      nodeUrl: url,
      serverStatus: status,
      clearError: true,
    );
    return status;
  }

  /// Probes a node without adopting it, for the discovery list's ready or
  /// needs-setup indicator.
  Future<ServerStatusModel?> probe(String rawUrl) async {
    final probeClient = ApiClient(store: _store)
      ..useNode(ApiClient.normalizeNodeUrl(rawUrl));
    try {
      return await AuthDb(probeClient).status();
    } on ApiException {
      return null;
    } finally {
      probeClient.dispose();
    }
  }

  Future<void> setup({
    required String username,
    required String password,
    required String serverName,
    String email = '',
  }) async {
    await _run(() async {
      final device = await ref.read(deviceInfoProvider.future);
      final result = await _db.setup(
        username: username,
        password: password,
        serverName: serverName,
        email: email,
        deviceName: device.name,
        platform: device.platform,
      );
      await _adopt(result);
    });
  }

  Future<void> register({
    required String username,
    required String password,
    required String inviteCode,
    String email = '',
  }) async {
    await _run(() async {
      final device = await ref.read(deviceInfoProvider.future);
      final result = await _db.register(
        username: username,
        password: password,
        inviteCode: inviteCode,
        email: email,
        deviceName: device.name,
        platform: device.platform,
      );
      await _adopt(result);
    });
  }

  Future<void> signIn({
    required String username,
    required String password,
    String totpCode = '',
  }) async {
    await _run(() async {
      final device = await ref.read(deviceInfoProvider.future);
      final result = await _db.login(
        username: username,
        password: password,
        totpCode: totpCode,
        deviceName: device.name,
        platform: device.platform,
      );
      await _adopt(result);
    });
  }

  /// A device held for approval polls every four to five seconds, no faster,
  /// so a phone in a pocket is not doing constant network work while it waits.
  void _startApprovalPolling(String sessionId) {
    _approvalPoll?.cancel();
    _approvalPoll = Timer.periodic(AppDurations.approvalPoll, (_) async {
      try {
        final result = await _db.sessionStatus(sessionId);
        if (result.tokens != null) {
          _approvalPoll?.cancel();
          await _adopt(result.tokens!);
          return;
        }
        if (result.status == 'denied' || result.status == 'revoked') {
          _approvalPoll?.cancel();
          await cancelPendingApproval(denied: true);
        }
      } on ApiException catch (error) {
        if (error.kind == ApiErrorKind.unauthorized) {
          _approvalPoll?.cancel();
          await cancelPendingApproval(denied: true);
        }
        // anything transient just waits for the next tick
      }
    });
  }

  /// Abandons a pending session cleanly, from the Cancel action on the waiting
  /// screen or after a denial.
  Future<void> cancelPendingApproval({bool denied = false}) async {
    _approvalPoll?.cancel();
    await _api.clearSession();
    state = state.copyWith(
      stage: SessionStage.signedOut,
      pendingSessionId: '',
      clearUser: true,
      error: denied ? const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'device denied',
        code: 'device_denied',
      ) : null,
    );
  }

  Future<void> _adopt(AuthResult result) async {
    if (result.pending) {
      _api.useTokens(accessToken: result.accessToken);
      state = state.copyWith(
        stage: SessionStage.pendingApproval,
        pendingSessionId: result.sessionId,
        busy: false,
        clearError: true,
      );
      _startApprovalPolling(result.sessionId);
      return;
    }

    _api.useTokens(accessToken: result.accessToken);
    await _store.writeTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      sessionId: result.sessionId,
    );

    final user = result.user ?? await _db.me();
    ServerStatusModel? status = state.serverStatus;
    try {
      status = await _db.status();
    } on ApiException {
      // keep whatever was already known
    }
    _afterSignIn(user, _api.baseUrl ?? state.nodeUrl, status);
  }

  void _afterSignIn(
    UserModel user,
    String nodeUrl,
    ServerStatusModel? status,
  ) {
    // order matters: a temporary password is the more urgent of the two, and
    // enrolling two factor on an account whose password is about to change
    // would be work done twice
    state = SessionState(
      stage: user.mustChangePassword
          ? SessionStage.mustChangePassword
          : user.mustEnableTotp
              ? SessionStage.mustEnableTotp
              : SessionStage.ready,
      user: user,
      nodeUrl: nodeUrl,
      serverStatus: status,
    );
    _connectSocket();

    // Anything that tried to load before this point did so without a usable
    // token, and a provider that has already failed stays failed until
    // something asks it again. That is what put "could not reach this server"
    // on the first screen after a device was approved, with a Try again button
    // that worked immediately.
    _refetchAfterSessionChange();
  }

  void _refetchAfterSessionChange() {
    ref.invalidate(librariesProvider);
    ref.invalidate(filesControllerProvider);
    // the listing providers were the ones actually showing the error. They
    // call keepAlive, so the failure from before there was a token outlived
    // the sign in that fixed it, and only the Try again button cleared it.
    refreshServerData(ref);
  }

  void _connectSocket() {
    final token = _api.accessToken;
    final url = _api.baseUrl;
    if (token == null || url == null) return;
    ref.read(webSocketProvider).connect(baseUrl: url, token: token);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _run(() async {
      await _db.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final user = await _db.me();
      state = state.copyWith(stage: SessionStage.ready, user: user);
      _connectSocket();
    });
  }

  /// Re-reads the account, after a quota change or a profile edit.
  Future<void> refreshUser() async {
    try {
      final user = await _db.me();
      state = state.copyWith(user: user);
    } on ApiException {
      // a transient failure here is not worth surfacing
    }
  }

  /// Applies a live quota update from the websocket without a round trip.
  void applyQuota({required int quotaBytes, required int quotaBytesUsed}) {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(
      user: user.copyWith(
        quotaBytes: quotaBytes,
        quotaBytesUsed: quotaBytesUsed,
      ),
    );
  }

  Future<void> signOut() async {
    _approvalPoll?.cancel();
    try {
      await _db.logout();
    } on ApiException {
      // signing out locally matters more than the server acknowledging it
    }
    ref.read(webSocketProvider).disconnect();
    await _api.clearSession();

    // everything device local goes too: the folder names this account browsed,
    // the files it kept offline, and anything still queued. The next person to
    // use this device has no business seeing any of it
    await ref.read(offlineFilesProvider).clear();
    await ref.read(localDbProvider).wipe();

    // wiping the database is not enough on its own. The listing providers keep
    // their last answer in memory, so without this the next server's home
    // screen opens showing the previous server's files, which then fail to open
    refreshServerData(ref);

    state = SessionState(
      stage: SessionStage.signedOut,
      nodeUrl: state.nodeUrl,
      serverStatus: state.serverStatus,
    );
  }

  /// How many times in a row a node has to miss before it is treated as gone.
  static const _goneAfter = 3;
  static const _retryGap = Duration(milliseconds: 600);

  /// Whether a node that just failed to answer is actually gone, or whether
  /// the device simply has no network at the moment.
  ///
  /// A single failed request cannot tell those apart, and they call for
  /// opposite responses: forgetting a server because someone walked out of
  /// Wi-Fi range would make them re-add it constantly. So the device has to be
  /// demonstrably online, and the node has to miss several attempts in a row,
  /// before it is dropped. If connectivity itself cannot be read the answer is
  /// no, which errs towards keeping a server that might still be there.
  Future<bool> _nodeIsGone() async {
    // the caller's own attempt has already failed by the time this runs
    for (var remaining = _goneAfter - 1; remaining > 0; remaining--) {
      if (!await _hasNetwork()) return false;
      await Future<void>.delayed(_retryGap);
      try {
        await _db.status();
        // it answered, so that was a bad moment rather than a dead server
        return false;
      } on ApiException {
        // still nothing, keep going
      }
    }
    return _hasNetwork();
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } on Object {
      return false;
    }
  }

  /// Confirms enrolment with a code from the authenticator.
  ///
  /// The user is re-read afterwards rather than assumed: the server decides
  /// whether two factor is on, and an admin only leaves the enrolment gate
  /// because the server says the flag flipped.
  Future<void> confirmTwoFactor(String code) async {
    await _db.confirmTotp(code);
    final user = await _db.me();
    state = state.copyWith(
      user: user,
      stage: user.mustChangePassword
          ? SessionStage.mustChangePassword
          : SessionStage.ready,
      clearError: true,
    );
  }

  /// Forgets the node entirely and returns to onboarding.
  Future<void> switchNode() async {
    await signOut();
    await _store.clearNodeUrl();
    state = const SessionState(stage: SessionStage.noNode);
  }

  void _handleSessionLost() {
    ref.read(webSocketProvider).disconnect();
    state = state.copyWith(
      stage: SessionStage.signedOut,
      clearUser: true,
      error: const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'session ended',
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await action();
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error);
      rethrow;
    } finally {
      if (state.busy) state = state.copyWith(busy: false);
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in account on its own, so a widget that only needs the avatar
/// does not rebuild when the stage changes.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(sessionProvider.select((s) => s.user));
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider.select((s) => s.isAdmin));
});

final authDbProvider = Provider<AuthDb>((ref) {
  return AuthDb(ref.watch(apiClientProvider));
});

/// What the server hands back when enrolment starts.
typedef TotpEnrollment = ({
  String secret,
  String otpauthUrl,
  List<String> recoveryCodes,
});

/// Starts enrolment and holds the result for the setup screen.
///
/// autoDispose so leaving the screen and coming back asks for a fresh secret
/// rather than showing one that may already have been abandoned.
final totpEnrollmentProvider =
    FutureProvider.autoDispose<TotpEnrollment>((ref) async {
  return AuthDb(ref.read(apiClientProvider)).beginTotp();
});
