import '../../../imports.dart';
import 'desktop/storage_page_desktop.dart';
import 'mobile/storage_page_mobile.dart';

/// Storage: a card per library with its own numbers, a combined total at the
/// top, and, for an admin, the detected drives.
class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const StoragePageMobile(),
      desktop: (_) => const StoragePageDesktop(),
    );
  }
}
