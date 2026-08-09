import '../../../imports.dart';
import 'desktop/settings_page_desktop.dart';
import 'mobile/settings_page_mobile.dart';

/// Settings. The route carries which section, so a deep link into Devices
/// lands exactly there on either breakpoint.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.section});

  final String? section;

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => SettingsPageMobile(section: section),
      desktop: (_) => SettingsPageDesktop(section: section),
    );
  }
}
