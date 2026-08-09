import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import '../../../imports.dart';
import '../controller/update_controller.dart';
import '../models/release_model.dart';
import '../services/update_service.dart';
import 'about_row.dart';

/// The version card: what is installed, and what to do about it. The check
/// happens here rather than on the releases page in a browser, since a link
/// out is just an extra step most people will not take.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key, required this.version});

  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);

    return AboutCard(
      title: l10n.versionSection,
      children: <Widget>[
        AboutRow(label: l10n.versionInstalled, value: version),
        if (!UpdateService.canUpdateInPlace)
          AboutRow(label: l10n.updateCheck, value: l10n.updateManualOnly)
        else
          switch (state) {
            UpdateIdle() || UpdateFailed() => AboutRow(
                label: l10n.updateCheck,
                glyph: LdGlyph.refresh,
                value: state is UpdateFailed ? state.message : null,
                onTap: controller.check,
              ),
            UpdateChecking() => _Busy(label: l10n.updateChecking),
            UpdateUpToDate(:final version) => AboutRow(
                label: l10n.updateUpToDate,
                glyph: LdGlyph.check,
                value: l10n.updateUpToDateBody(version),
              ),
            UpdateAvailable(:final release) => _Available(release: release),
            UpdateDownloading() => _Progress(state: state),
            UpdateInstalling() => _Busy(label: l10n.updateInstalling),
          },
      ],
    );
  }
}

/// A new release, its notes, and the one button that acts on it.
class _Available extends ConsumerWidget {
  const _Available({required this.release});

  final ReleaseModel release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const LdIcon(
                LdGlyph.download,
                size: 18,
                color: LdColors.accentPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.updateAvailable(release.version),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (release.size > 0)
                Text(
                  LdFormat.bytes(context, release.size),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: LdColors.foregroundSecondary,
                      ),
                ),
            ],
          ),
          if (release.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              l10n.updateNotes.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: LdColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 8),
            // bounded, because a release note can run to pages and this is a
            // card in a settings list, not the changelog
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Text(
                  release.notes,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: LdColors.foregroundSecondary,
                        height: 1.5,
                      ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          LdButton(
            label: l10n.updateInstall,
            glyph: LdGlyph.download,
            compact: true,
            onPressed: () =>
                ref.read(updateControllerProvider.notifier).install(release),
          ),
          const SizedBox(height: 10),
          Text(
            defaultTargetPlatform == TargetPlatform.android
                ? l10n.updateAndroidNote
                : l10n.updateRestartNote,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: LdColors.foregroundMuted,
                ),
          ),
        ],
      ),
    );
  }
}

/// The download, with a real fraction when the server gave a length.
class _Progress extends ConsumerWidget {
  const _Progress({required this.state});

  final UpdateDownloading state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final fraction = state.fraction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.updateDownloading,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                fraction == null
                    ? LdFormat.bytes(context, state.received)
                    : '${(fraction * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: LdColors.foregroundSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: LdColors.backgroundSunken,
              valueColor: const AlwaysStoppedAnimation<Color>(
                LdColors.accentPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LdButton.secondary(
            label: l10n.actionCancel,
            compact: true,
            onPressed: ref.read(updateControllerProvider.notifier).cancel,
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: <Widget>[
          const LdSpinner(size: 17),
          const SizedBox(width: 14),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
