import '../../../imports.dart';
import '../providers/discovery_providers.dart';

/// The scan, as a radar with each server appearing on the dial, plus the list
/// of what was found underneath it.
///
/// Finding nothing is a legitimate outcome, not an error: a different subnet,
/// discovery turned off on that server, or a firewall in the way all look the
/// same from here, and the manual address field is always available alongside.
class DiscoveryRadar extends StatelessWidget {
  const DiscoveryRadar({
    super.key,
    required this.discovered,
    required this.onSelected,
    this.size = 220,
  });

  final AsyncValue<List<DiscoveredNode>> discovered;
  final ValueChanged<DiscoveredNode> onSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nodes = discovered.maybeWhen(
      data: (list) => list,
      orElse: () => const <DiscoveredNode>[],
    );
    final scanning = discovered.isLoading;

    return Column(
      children: <Widget>[
        LdRadar(
          size: size,
          scanning: scanning,
          blips: <LdRadarBlip>[
            for (final node in nodes)
              LdRadarBlip(seed: node.url, ready: node.ready),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: LdMotion.standard,
          child: Text(
            scanning
                ? l10n.scanningNetwork
                : nodes.isEmpty
                    ? l10n.nothingFound
                    : l10n.itemCount(nodes.length),
            key: ValueKey<String>('$scanning-${nodes.length}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (!scanning && nodes.isEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l10n.nothingFoundBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 18),
        // each result slides in as it arrives rather than the list jumping
        for (var i = 0; i < nodes.length; i++)
          _Arriving(
            key: ValueKey<String>(nodes[i].url),
            delay: Duration(milliseconds: 60 * i),
            child: LdNodeListItem(
              title: nodes[i].name,
              subtitle: nodes[i].url,
              glyph: LdGlyph.server,
              status: nodes[i].ready ? l10n.serverReady : l10n.serverNeedsSetup,
              statusColor: nodes[i].ready
                  ? LdColors.fileSpreadsheet
                  : LdColors.filePresentation,
              onTap: () => onSelected(nodes[i]),
            ),
          ),
      ],
    );
  }
}

/// Fades and lifts one result into place.
class _Arriving extends StatefulWidget {
  const _Arriving({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_Arriving> createState() => _ArrivingState();
}

class _ArrivingState extends State<_Arriving>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LdMotion.standard,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final eased = LdMotion.curve.transform(_controller.value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}


/// Just the dial, for a layout that puts the scan and the results in separate
/// panes.
class DiscoveryRadarDial extends StatelessWidget {
  const DiscoveryRadarDial({
    super.key,
    required this.discovered,
    this.size = 300,
  });

  final AsyncValue<List<DiscoveredNode>> discovered;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nodes = discovered.maybeWhen(
      data: (list) => list,
      orElse: () => const <DiscoveredNode>[],
    );
    final scanning = discovered.isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LdRadar(
          size: size,
          scanning: scanning,
          blips: <LdRadarBlip>[
            for (final node in nodes)
              LdRadarBlip(seed: node.url, ready: node.ready),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: LdMotion.standard,
          child: Text(
            scanning ? l10n.scanningNetwork : l10n.scanForServers,
            key: ValueKey<bool>(scanning),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Just the results, for the same reason.
class DiscoveryResultList extends StatelessWidget {
  const DiscoveryResultList({
    super.key,
    required this.discovered,
    required this.onSelected,
  });

  final AsyncValue<List<DiscoveredNode>> discovered;
  final ValueChanged<DiscoveredNode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nodes = discovered.maybeWhen(
      data: (list) => list,
      orElse: () => const <DiscoveredNode>[],
    );

    if (discovered.isLoading) {
      return const Column(
        children: <Widget>[
          LdSkeleton(width: double.infinity, height: 72, radius: 14),
          SizedBox(height: 10),
          LdSkeleton(width: double.infinity, height: 72, radius: 14),
        ],
      );
    }
    if (nodes.isEmpty) {
      return LdEmptyState(
        title: l10n.nothingFound,
        message: l10n.nothingFoundBody,
        glyph: LdGlyph.wifi,
        compact: true,
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < nodes.length; i++)
          _Arriving(
            key: ValueKey<String>(nodes[i].url),
            delay: Duration(milliseconds: 60 * i),
            child: LdNodeListItem(
              title: nodes[i].name,
              subtitle: nodes[i].url,
              glyph: LdGlyph.server,
              status: nodes[i].ready ? l10n.serverReady : l10n.serverNeedsSetup,
              statusColor: nodes[i].ready
                  ? LdColors.fileSpreadsheet
                  : LdColors.filePresentation,
              onTap: () => onSelected(nodes[i]),
            ),
          ),
      ],
    );
  }
}
