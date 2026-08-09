import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../settings_section.dart';
import '../../widgets/account_card.dart';

/// Settings, on a phone: one section at a time, pushed and popped, with a back
/// control in the header rather than a list beside the content.
class SettingsPageMobile extends ConsumerWidget {
  const SettingsPageMobile({super.key, this.section});

  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final isAdmin = ref.watch(isAdminProvider);

    final current = SettingsSection.fromId(section);
    final body = current?.build() ?? _Overview(isAdmin: isAdmin);

    return Column(
      children: <Widget>[
        LdPageHeader(
          title: _titleFor(l10n, section),
          onBack:
              section == null ? null : () => context.go(Routes.settings),
        ),
        if (section == null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            child: const AccountCard(),
          ),
        Expanded(child: body),
      ],
    );
  }

  static String _titleFor(L10n l10n, String? section) =>
      SettingsSection.fromId(section)?.title(l10n) ?? l10n.settings;
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    // A settings row that says only what it is makes you open it to find out
    // what it is set to, then come back. Every row that has an answer shows it,
    // which is what turns a list of destinations into a summary of the account.
    final locale = ref.watch(localeProvider);
    final totpOn = ref.watch(currentUserProvider)?.totpEnabled ?? false;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        16,
        context.pagePadding,
        120,
      ),
      children: <Widget>[
        LdSettingGroup(
          title: l10n.settingsAccount,
          children: <Widget>[
            LdSettingRow(
              label: SettingsSection.language.title(l10n),
              glyph: SettingsSection.language.glyph,
              // null means the app is following the device, which resolves to
              // English everywhere the app is not translated
              description: locale?.languageCode == 'ar'
                  ? l10n.languageArabic
                  : l10n.languageEnglish,
              onTap: () => context.go(SettingsSection.language.route),
            ),
            _SectionRow(SettingsSection.devices),
            // one section, shared with desktop, so enrolment cannot exist on
            // one platform and be missing on the other
            LdSettingRow(
              label: SettingsSection.twoFactor.title(l10n),
              glyph: SettingsSection.twoFactor.glyph,
              description: totpOn ? l10n.twoFactorOn : l10n.twoFactorOff,
              onTap: () => context.go(SettingsSection.twoFactor.route),
            ),
            LdSettingRow(
              label: l10n.activity,
              glyph: LdGlyph.activity,
              onTap: () => context.go(Routes.activity),
            ),
          ],
        ),
        LdSettingGroup(
          title: l10n.storage,
          children: <Widget>[
            LdSettingRow(
              label: l10n.storage,
              glyph: LdGlyph.drive,
              // this account's own usage, not the drive's. The two numbers are
              // different and the storage screen explains that; here the one
              // worth knowing at a glance is your own
              description: switch (ref.watch(currentUserProvider)) {
                final user? when user.hasQuota => l10n.storageUsedOf(
                    LdFormat.bytes(context, user.quotaBytesUsed),
                    LdFormat.bytes(context, user.quotaBytes),
                  ),
                final user? => LdFormat.bytes(context, user.quotaBytesUsed),
                _ => null,
              },
              onTap: () => context.go(Routes.storage),
            ),
            // deliberately beside the server storage row: two different
            // numbers, and seeing them together makes the difference
            // between them obvious
            if (SettingsSection.downloads.isAvailable(isAdmin: isAdmin))
              _SectionRow(SettingsSection.downloads),
            LdSettingRow(
              label: l10n.trash,
              glyph: LdGlyph.trash,
              onTap: () => context.go(Routes.trash),
            ),
          ],
        ),
        if (isAdmin)
          LdSettingGroup(
            title: l10n.settingsServer,
            children: <Widget>[
              _SectionRow(SettingsSection.users),
              _SectionRow(SettingsSection.server),
            ],
          ),
        LdSettingGroup(
          title: l10n.settingsAbout,
          children: <Widget>[
            _SectionRow(SettingsSection.about),
            LdSettingRow(
              label: l10n.settingsSwitchNode,
              glyph: LdGlyph.server,
              onTap: () => ref.read(sessionProvider.notifier).switchNode(),
            ),
            LdSettingRow(
              label: l10n.settingsSignOut,
              glyph: LdGlyph.logout,
              destructive: true,
              onTap: () => ref.read(sessionProvider.notifier).signOut(),
            ),
          ],
        ),
      ],
    );
  }
}

// One row for one section, so the label, icon and destination all come from
// the same place the route does.
class _SectionRow extends StatelessWidget {
  const _SectionRow(this.section);

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return LdSettingRow(
      label: section.title(L10n.of(context)),
      glyph: section.glyph,
      onTap: () => context.go(section.route),
    );
  }
}
