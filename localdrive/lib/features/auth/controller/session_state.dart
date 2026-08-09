import '../models/user_model.dart';

/// Where the app is in its connect, then sign in, then use lifecycle. The
/// router keys off exactly this, so there is one source of truth for what
/// screen a person should be looking at.
enum SessionStage {
  /// still reading secure storage on a cold start
  restoring,

  /// no node picked yet, so onboarding runs
  noNode,

  /// a node is picked but nobody is signed in
  signedOut,

  /// a device is waiting to be let in
  pendingApproval,

  /// signed in, but on a temporary password and blocked from everything else
  mustChangePassword,

  /// an admin signed in without two factor set up. The only way on is to
  /// finish enrolling, the same shape as mustChangePassword.
  mustEnableTotp,

  /// signed in and working
  ready,
}

/// The immutable session state.
class SessionState {
  const SessionState({
    this.stage = SessionStage.restoring,
    this.user,
    this.serverStatus,
    this.nodeUrl = '',
    this.pendingSessionId = '',
    this.busy = false,
    this.error,
  });

  final SessionStage stage;
  final UserModel? user;
  final ServerStatusModel? serverStatus;
  final String nodeUrl;
  final String pendingSessionId;
  final bool busy;
  final Object? error;

  bool get isSignedIn =>
      stage == SessionStage.ready || stage == SessionStage.mustChangePassword;

  bool get isAdmin => user?.isAdmin ?? false;

  String get serverName => serverStatus?.name ?? '';

  SessionState copyWith({
    SessionStage? stage,
    UserModel? user,
    ServerStatusModel? serverStatus,
    String? nodeUrl,
    String? pendingSessionId,
    bool? busy,
    Object? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      SessionState(
        stage: stage ?? this.stage,
        user: clearUser ? null : (user ?? this.user),
        serverStatus: serverStatus ?? this.serverStatus,
        nodeUrl: nodeUrl ?? this.nodeUrl,
        pendingSessionId: pendingSessionId ?? this.pendingSessionId,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}
