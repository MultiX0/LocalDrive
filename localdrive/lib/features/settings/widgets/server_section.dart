import '../../../imports.dart';
import '../providers/settings_providers.dart';

/// The handful of everyday preferences that are editable at runtime rather
/// than through a redeploy.
class ServerSection extends ConsumerWidget {
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final settings = ref.watch(serverSettingsProvider);

    return LdAsync<ServerSettingsModel>(
      value: settings,
      errorCopy: LdFormat.errorCopy(context),
      onRetry: () => ref.invalidate(serverSettingsProvider),
      loading: const LdCardSkeleton(cards: 2),
      data: (current) {
        final controller = ref.read(serverSettingsProvider.notifier);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            16,
            context.pagePadding,
            120,
          ),
          children: <Widget>[
            LdSettingGroup(
              title: l10n.settingsServer,
              children: <Widget>[
                LdSettingRow(
                  label: l10n.settingsRequireApproval,
                  description: l10n.settingsRequireApprovalNote,
                  glyph: LdGlyph.device,
                  trailing: LdSwitch(
                    value: current.requireDeviceApproval,
                    onChanged: (value) =>
                        controller.apply(requireDeviceApproval: value),
                  ),
                ),
                LdSettingRow(
                  label: l10n.settingsLanDiscovery,
                  description: l10n.settingsLanDiscoveryNote,
                  glyph: LdGlyph.wifi,
                  trailing: LdSwitch(
                    value: current.enableLanDiscovery,
                    onChanged: (value) =>
                        controller.apply(enableLanDiscovery: value),
                  ),
                ),
                LdSettingRow(
                  label: l10n.settingsSelfRegistration,
                  description: l10n.settingsSelfRegistrationNote,
                  glyph: LdGlyph.people,
                  trailing: LdSwitch(
                    value: current.allowSelfRegistration,
                    onChanged: (value) =>
                        controller.apply(allowSelfRegistration: value),
                  ),
                ),
              ],
            ),
            LdSettingGroup(
              title: l10n.settingsAbout,
              children: <Widget>[
                LdSettingRow(
                  label: l10n.serverNameLabel,
                  description: current.serverName,
                  glyph: LdGlyph.server,
                  onTap: () => _rename(context, ref, current.serverName),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController(text: current);
    final name = await LdBottomSheet.show<String>(
      context,
      title: l10n.serverNameLabel,
      scrollable: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdTextField(
            controller: controller,
            label: l10n.serverNameLabel,
            hint: l10n.serverNameHint,
            autofocus: true,
          ),
          const SizedBox(height: 20),
          LdButton(
            label: l10n.actionSave,
            onPressed: () => Navigator.of(sheetContext).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(serverSettingsProvider.notifier).apply(
          serverName: name.trim(),
        );
  }
}
