import '../../../imports.dart';
import 'desktop/setup_page_desktop.dart';
import 'mobile/setup_page_mobile.dart';

/// Step four, first run branch: this node has zero accounts, and whoever
/// completes this becomes its admin. The server refuses it the moment a single
/// user exists.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const SetupPageMobile(),
      desktop: (_) => const SetupPageDesktop(),
    );
  }
}
