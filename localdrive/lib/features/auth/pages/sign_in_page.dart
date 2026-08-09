import '../../../imports.dart';
import 'desktop/sign_in_page_desktop.dart';
import 'mobile/sign_in_page_mobile.dart';

/// Sign in, and create account with an invite code. One screen with two modes,
/// because they are the same form with one extra field.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key, this.createMode = false, this.inviteCode = ''});

  final bool createMode;

  /// pre-filled when someone arrived through an invite link or a scanned code
  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => SignInPageMobile(
        createMode: createMode,
        inviteCode: inviteCode,
      ),
      desktop: (_) => SignInPageDesktop(
        createMode: createMode,
        inviteCode: inviteCode,
      ),
    );
  }
}
