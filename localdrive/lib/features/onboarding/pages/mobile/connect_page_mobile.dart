import '../../../../imports.dart';
import '../../controller/connect_controller.dart';
import '../../providers/discovery_providers.dart';
import '../../widgets/discovery_radar.dart';

/// Connect, on a phone: one scrolling column, radar first, address field
/// underneath, because there is no room to put them side by side.
class ConnectPageMobile extends HookConsumerWidget {
  const ConnectPageMobile({super.key});

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

    return LdScaffold(
      showBack: true,
      onBack: () => context.go(Routes.welcome),
      actions: const <Widget>[LdLanguageToggle(compact: true)],
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: 8,
            ),
            children: <Widget>[
              Text(
                l10n.connectTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.connectBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              DiscoveryRadar(
                discovered: discovered,
                onSelected: (node) {
                  address.text = node.url;
                  connect(node.url);
                },
              ),
              LdButton.text(
                label: l10n.scanAgain,
                glyph: LdGlyph.refresh,
                onPressed: () => ref.invalidate(discoveryProvider),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
