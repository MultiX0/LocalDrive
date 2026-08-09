import '../../../imports.dart';
import 'desktop/trash_page_desktop.dart';
import 'mobile/trash_page_mobile.dart';

/// The trash, with the purge policy stated on the screen rather than left as
/// a surprise, and restore or permanent delete per item.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const TrashPageMobile(),
      desktop: (_) => const TrashPageDesktop(),
    );
  }
}
