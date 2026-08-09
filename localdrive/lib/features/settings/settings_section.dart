import 'package:flutter/widgets.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/ld_icons.dart';
import '../../l10n/generated/app_localizations.dart';
import '../offline/controller/offline_controller.dart';
import '../about/pages/about_page.dart';
import '../auth/pages/two_factor_setup_page.dart';
import 'widgets/devices_section.dart';
import 'widgets/language_section.dart';
import 'widgets/offline_section.dart';
import 'widgets/server_section.dart';
import 'widgets/users_section.dart';

// The sections of Settings, declared once.
//
// The id used to be a bare string repeated in five places: the route, both
// page layouts, the title lookup and the sidebar. Adding a section meant
// finding all five, and getting one wrong produced a route that resolved to a
// blank page rather than an error.
enum SettingsSection {
  account('account'),
  devices('devices'),
  language('language'),
  twoFactor('two-factor'),
  downloads('downloads'),
  users('users'),
  server('server'),
  about('about');

  const SettingsSection(this.id);

  /// The path segment under /settings, and the value the page is built with.
  final String id;

  String get route => Routes.settingsSection(id);

  static SettingsSection? fromId(String? id) {
    if (id == null) return null;
    for (final section in values) {
      if (section.id == id) return section;
    }
    return null;
  }

  /// The sections an account can actually reach. Users and server are admin
  /// only, and downloads needs a platform that can keep files offline.
  static List<SettingsSection> visibleTo({required bool isAdmin}) =>
      values.where((section) => section.isAvailable(isAdmin: isAdmin)).toList();

  bool isAvailable({required bool isAdmin}) => switch (this) {
        SettingsSection.users || SettingsSection.server => isAdmin,
        SettingsSection.downloads => OfflineController.isSupported,
        _ => true,
      };

  bool get isAdminOnly =>
      this == SettingsSection.users || this == SettingsSection.server;

  String title(L10n l10n) => switch (this) {
        SettingsSection.account => l10n.settingsAccount,
        SettingsSection.devices => l10n.devices,
        SettingsSection.language => l10n.settingsLanguage,
        SettingsSection.twoFactor => l10n.settingsTwoFactor,
        SettingsSection.downloads => l10n.offlineDownloadsTitle,
        SettingsSection.users => l10n.settingsUsers,
        SettingsSection.server => l10n.settingsServer,
        SettingsSection.about => l10n.settingsAbout,
      };

  LdGlyph get glyph => switch (this) {
        SettingsSection.account => LdGlyph.person,
        SettingsSection.devices => LdGlyph.device,
        SettingsSection.language => LdGlyph.language,
        SettingsSection.twoFactor => LdGlyph.lock,
        SettingsSection.downloads => LdGlyph.offlineReady,
        SettingsSection.users => LdGlyph.people,
        SettingsSection.server => LdGlyph.server,
        SettingsSection.about => LdGlyph.info,
      };

  /// Null means the caller supplies the panel. Account looks different in the
  /// two layouts and About is a page rather than a panel, so neither is built
  /// here.
  Widget? build() => switch (this) {
        SettingsSection.account => null,
        SettingsSection.devices => const DevicesSection(),
        SettingsSection.language => const LanguageSection(),
        // the same screen the phone opens, so enrolment is identical everywhere
        SettingsSection.twoFactor => const TwoFactorSetupPage(embedded: true),
        SettingsSection.downloads => const OfflineSection(),
        SettingsSection.users => const UsersSection(),
        SettingsSection.server => const ServerSection(),
        // the same page the phone pushes, minus its own scaffold, because the
        // settings shell already draws the header around it
        SettingsSection.about => const AboutPage(embedded: true),
      };
}
