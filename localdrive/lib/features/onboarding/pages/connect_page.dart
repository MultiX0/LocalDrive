import '../../../imports.dart';
import 'desktop/connect_page_desktop.dart';
import 'mobile/connect_page_mobile.dart';

/// Step two of onboarding. The scan starts on entry, results populate live,
/// and the manual address field is always available beside them, because
/// discovery can legitimately find nothing.
class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const ConnectPageMobile(),
      desktop: (_) => const ConnectPageDesktop(),
    );
  }
}
