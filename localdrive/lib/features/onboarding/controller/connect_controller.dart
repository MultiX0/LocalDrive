import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';

/// What the connect step is doing right now.
class ConnectState {
  const ConnectState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Connecting is the same act on a phone and on a desktop, so it lives here
/// rather than being written twice in two layouts.
class ConnectController {
  const ConnectController(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Points the app at a node and moves on. Selecting a discovered result only
  /// fills in the address; the very next screen is still the normal sign in or
  /// create account flow.
  Future<String?> connect(String url) async {
    final l10n = L10n.of(context);
    if (url.trim().isEmpty) return null;
    try {
      await ref.read(sessionProvider.notifier).connectTo(url);
      if (context.mounted) context.go(Routes.language);
      return null;
    } on ApiException catch (failure) {
      return failure.kind == ApiErrorKind.unreachable
          ? l10n.couldNotReachServer
          : failure.message;
    }
  }
}
