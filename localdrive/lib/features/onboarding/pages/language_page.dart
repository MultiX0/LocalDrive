import '../../../imports.dart';
import 'desktop/language_page_desktop.dart';
import 'mobile/language_page_mobile.dart';

/// Step three of onboarding. Picking a language here also proves the typeface
/// swap works before anything else in the app depends on it.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => const LanguagePageMobile(),
      desktop: (_) => const LanguagePageDesktop(),
    );
  }
}
