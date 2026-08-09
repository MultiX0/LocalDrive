import '../../../imports.dart';
import 'desktop/shared_page_desktop.dart';
import 'mobile/shared_page_mobile.dart';

/// The dedicated Shared tab: only what other people have shared, each item
/// already labelled with whose it is by the owner badge on its tile.
class SharedPage extends StatelessWidget {
  const SharedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const SharedPageMobile(),
      desktop: (_) => const SharedPageDesktop(),
    );
  }
}
