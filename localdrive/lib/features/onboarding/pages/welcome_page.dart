import '../../../imports.dart';
import 'desktop/welcome_page_desktop.dart';
import 'mobile/welcome_page_mobile.dart';

/// Step one of onboarding.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const WelcomePageMobile(),
      desktop: (_) => const WelcomePageDesktop(),
    );
  }
}
