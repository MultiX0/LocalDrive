import '../../../imports.dart';
import 'desktop/gallery_page_desktop.dart';
import 'mobile/gallery_page_mobile.dart';

/// Every picture and clip, in one place, in the order they were taken.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const GalleryPageMobile(),
      desktop: (_) => const GalleryPageDesktop(),
    );
  }
}
