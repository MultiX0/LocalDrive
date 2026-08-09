import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../settings_section.dart';
import '../../widgets/account_card.dart';

/// Settings, on desktop.
///
/// A phone pushes one section at a time and pops back. A wide window has room
/// for both at once, so the sections live down the left and the chosen one
/// fills the rest, with no navigation in between.
class SettingsPageDesktop extends ConsumerWidget {
  const SettingsPageDesktop({super.key, this.section});

  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final current = SettingsSection.fromId(section) ?? SettingsSection.account;

    // About used to be filtered out here on the grounds that it is a page
    // rather than a panel. The desktop content column has no About row either,
    // so between the two there was no way to reach it on a desktop at all: the
    // version number, the update check and the licence were only findable by
    // typing the route. It is a section like the rest.
    final sections = SettingsSection.visibleTo(isAdmin: isAdmin)
        .map((s) => (id: s.id, label: s.title(l10n), glyph: s.glyph))
        .toList();

    return LdDesktopScaffold(
      title: l10n.settings,
      actions: <Widget>[
        LdButton.secondary(
          label: l10n.settingsSignOut,
          glyph: LdGlyph.logout,
          compact: true,
          expand: false,
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
      body: LdMasterDetail(
        sections: sections,
        selected: current.id,
        onSelected: (id) => context.go(Routes.settingsSection(id)),
        child: current.build() ?? const _AccountSection(),
      ),
    );
  }
}

/// The account section, which on desktop is a reading column rather than a
/// full width sprawl.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AccountCard(),
              const SizedBox(height: 24),
              LdSettingGroup(
                title: l10n.storage,
                children: <Widget>[
                  LdSettingRow(
                    label: l10n.storage,
                    glyph: LdGlyph.drive,
                    onTap: () => context.go(Routes.storage),
                  ),
                  LdSettingRow(
                    label: l10n.trash,
                    glyph: LdGlyph.trash,
                    onTap: () => context.go(Routes.trash),
                  ),
                  LdSettingRow(
                    label: l10n.activity,
                    glyph: LdGlyph.activity,
                    onTap: () => context.go(Routes.activity),
                  ),
                ],
              ),
              LdSettingGroup(
                title: l10n.settingsAbout,
                children: <Widget>[
                  LdSettingRow(
                    label: l10n.settingsSwitchNode,
                    glyph: LdGlyph.server,
                    onTap: () =>
                        ref.read(sessionProvider.notifier).switchNode(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
