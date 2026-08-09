import '../../../../imports.dart';
import '../../controller/connect_controller.dart';
import '../../providers/discovery_providers.dart';
import '../../widgets/discovery_radar.dart';

/// Connect, on desktop: two panes.
///
/// A wide window can show the radar sweeping on one side while the address
/// field and the results sit on the other, so nothing scrolls out of view and
/// the scan stays visible the whole time. That is a different design, not the
/// phone layout stretched.
class ConnectPageDesktop extends HookConsumerWidget {
  const ConnectPageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final discovered = ref.watch(discoveryProvider);
    final address = useTextEditingController();
    final busy = useState(false);
    final error = useState<String?>(null);

    Future<void> connect(String url) async {
      busy.value = true;
      error.value = await ConnectController(context, ref).connect(url);
      if (context.mounted) busy.value = false;
    }

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            // the scan, large, on its own
            Expanded(
              flex: 5,
              child: Container(
                color: LdColors.backgroundSunken,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const LdLogo(size: 64, stage: LdLogoStage.connected),
                        const SizedBox(height: 32),
                        DiscoveryRadarDial(discovered: discovered, size: 300),
                        const SizedBox(height: 24),
                        LdButton.text(
                          label: l10n.scanAgain,
                          glyph: LdGlyph.refresh,
                          onPressed: () => ref.invalidate(discoveryProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // the choices, on the other
            Expanded(
              flex: 6,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(40),
                    children: <Widget>[
                      Text(
                        l10n.connectTitle,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.connectBody,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: LdColors.foregroundSecondary,
                            ),
                      ),
                      const SizedBox(height: 28),
                      DiscoveryResultList(
                        discovered: discovered,
                        onSelected: (node) {
                          address.text = node.url;
                          connect(node.url);
                        },
                      ),
                      const SizedBox(height: 20),
                      LdTextField(
                        controller: address,
                        label: l10n.enterAddressManually,
                        hint: l10n.addressHint,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        prefixGlyph: LdGlyph.server,
                        errorText: error.value,
                        onSubmitted: connect,
                      ),
                      const SizedBox(height: 20),
                      LdButton(
                        label: l10n.connectAction,
                        busy: busy.value,
                        onPressed: () => connect(address.text),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: LdButton.text(
                          label: l10n.actionBack,
                          glyph: LdGlyph.chevronLeft,
                          onPressed: () => context.go(Routes.welcome),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
