import 'dart:async';

import 'package:flutter/services.dart';

import '../../../imports.dart';
import '../../files/models/node_model.dart';
import '../providers/nearby_providers.dart';
import '../providers/share_providers.dart';

/// Which half of the share sheet is showing. The two are kept distinct on
/// purpose: giving a household member access is a different act from putting
/// something on the open internet behind a link.
enum ShareMode { people, link }

/// The one share sheet, in both modes.
Future<void> showShareSheet(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
) {
  final l10n = L10n.of(context);
  return LdBottomSheet.show<void>(
    context,
    title: l10n.actionShare,
    subtitle: node.name,
    builder: (sheetContext) => _ShareSheetBody(node: node),
  );
}

class _ShareSheetBody extends HookConsumerWidget {
  const _ShareSheetBody({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final mode = useState(ShareMode.people);

    // iOS shows a system prompt the first time anything touches multicast.
    // This explains what it is for before that appears, so a no is an informed
    // one rather than a reflex
    useEffect(() {
      unawaited(_explainLocalNetwork(context, ref));
      return null;
    }, const <Object>[]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LdSegmented<ShareMode>(
          selected: mode.value,
          onChanged: (next) => mode.value = next,
          segments: <ShareMode, String>{
            ShareMode.people: l10n.sharePeopleTab,
            ShareMode.link: l10n.shareLinkTab,
          },
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: LdMotion.standard,
          curve: LdMotion.curve,
          child: mode.value == ShareMode.people
              ? _PeopleMode(node: node)
              : _LinkMode(node: node),
        ),
      ],
    );
  }
}

/// Tap a face, pick view or edit. Nothing in here is a text field.
class _PeopleMode extends HookConsumerWidget {
  const _PeopleMode({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final people = ref.watch(peopleProvider);
    final grants = ref.watch(nodeGrantsProvider(node.id));
    final pendingRole = useState('viewer');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(l10n.sharePeopleHint,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        LdSegmented<String>(
          selected: pendingRole.value,
          onChanged: (next) => pendingRole.value = next,
          segments: <String, String>{
            'viewer': l10n.shareRoleViewer,
            'editor': l10n.shareRoleEditor,
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              const LdIcon(
                LdGlyph.lock,
                size: 14,
                color: LdColors.foregroundSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.shareRoleNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LdAsync<List<PersonModel>>(
          value: people,
          compact: true,
          errorCopy: LdFormat.errorCopy(context),
          onRetry: () => ref.invalidate(peopleProvider),
          loading: const _PeopleSkeleton(),
          isEmpty: (list) => list.isEmpty,
          empty: () => LdEmptyState(
            title: l10n.emptyUsersTitle,
            message: l10n.emptyUsersBody,
            glyph: LdGlyph.people,
            compact: true,
          ),
          data: (list) {
            // who is on this network right now, from the presence beacon.
            // Watched here rather than passed down, so the beacon starts when
            // this list appears and stops when the sheet closes
            final nearby = ref.watch(nearbyIdsProvider);
            final granted = grants.maybeWhen(
              data: (rows) => <String, GrantModel>{
                for (final grant in rows) grant.userId: grant,
              },
              orElse: () => const <String, GrantModel>{},
            );
            // anyone nearby sorts above everyone else
            final sorted = <PersonModel>[
              for (final person in list)
                person.copyWith(nearby: nearby.contains(person.id)),
            ]..sort((a, b) {
                if (a.nearby != b.nearby) return a.nearby ? -1 : 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final person in sorted)
                  _PersonRow(
                    person: person,
                    grant: granted[person.userIdOrId],
                    onTap: (avatarCentre) async {
                      final existing = granted[person.id];
                      final db = ref.read(shareDbProvider);
                      if (existing != null) {
                        await db.revokeGrant(node.id, person.id);
                        ref.invalidate(nodeGrantsProvider(node.id));
                        return;
                      }

                      // the grant fires underneath while the item flies, so
                      // the animation never delays the actual sharing
                      final granting =
                          db.grant(node.id, person.id, pendingRole.value);
                      if (context.mounted) {
                        await LdSendFlight.play(
                          context,
                          from: Offset(
                            avatarCentre.dx,
                            avatarCentre.dy - 160,
                          ),
                          to: avatarCentre,
                          glyph: node.isFolder ? LdGlyph.folder : LdGlyph.file,
                          name: person.name,
                          seed: person.avatarSeed,
                        );
                      }
                      await granting;
                      ref.invalidate(nodeGrantsProvider(node.id));
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

extension on PersonModel {
  /// grants are keyed by user id; this keeps the lookup readable above
  String get userIdOrId => id;
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.grant,
    required this.onTap,
  });

  final PersonModel person;
  final GrantModel? grant;

  /// carries where the avatar actually is, so the flight lands on the face
  /// rather than at a guessed position
  final void Function(Offset avatarCentre) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final avatarKey = GlobalKey();

    return LdTappable(
      onTap: () {
        final box = avatarKey.currentContext?.findRenderObject() as RenderBox?;
        final centre = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        onTap(centre);
      },
      borderRadius: LdRadii.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            LdNearbyAvatar(
              key: avatarKey,
              name: person.name,
              seed: person.avatarSeed,
              size: 38,
              nearby: person.nearby,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(person.name,
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (person.nearby || grant != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      grant != null
                          ? (grant!.isEditor
                              ? l10n.shareRoleEditor
                              : l10n.shareRoleViewer)
                          : l10n.nearby,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: grant != null
                                ? LdColors.accentPrimary
                                : LdColors.fileSpreadsheet,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (grant != null)
              const LdIcon(
                LdGlyph.check,
                size: 20,
                color: LdColors.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSkeleton extends StatelessWidget {
  const _PeopleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: <Widget>[
                LdSkeleton.circle(size: 38),
                SizedBox(width: 12),
                LdSkeleton(width: 130, height: 13),
              ],
            ),
          ),
      ],
    );
  }
}

/// The public link half: expiry presets or an exact date, a password, and
/// download allowed or view only, all editable without changing the URL.
class _LinkMode extends HookConsumerWidget {
  const _LinkMode({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final shares = ref.watch(nodeSharesProvider(node.id));
    final busy = useState(false);

    return LdAsync<List<ShareModel>>(
      value: shares,
      compact: true,
      errorCopy: LdFormat.errorCopy(context),
      onRetry: () => ref.invalidate(nodeSharesProvider(node.id)),
      loading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: LdSpinner()),
      ),
      data: (list) {
        final active = list.where((share) => share.active).toList();
        if (active.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LdEmptyState(
                title: l10n.shareLinkTab,
                message: l10n.shareCreateLink,
                glyph: LdGlyph.link,
                compact: true,
              ),
              const SizedBox(height: 8),
              LdButton(
                label: l10n.shareCreateLink,
                glyph: LdGlyph.link,
                busy: busy.value,
                onPressed: () async {
                  busy.value = true;
                  try {
                    await ref.read(shareDbProvider).create(node.id);
                    ref.invalidate(nodeSharesProvider(node.id));
                  } finally {
                    busy.value = false;
                  }
                },
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final share in active) _LinkCard(share: share, node: node),
          ],
        );
      },
    );
  }
}

class _LinkCard extends HookConsumerWidget {
  const _LinkCard({required this.share, required this.node});

  final ShareModel share;
  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final db = ref.read(shareDbProvider);
    void refresh() => ref.invalidate(nodeSharesProvider(node.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LdColors.backgroundPrimary,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const LdIcon(
                LdGlyph.link,
                size: 18,
                color: LdColors.accentPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  share.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              LdTappable(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: share.url));
                  LdToast.success(context, l10n.actionCopied);
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: LdIcon(LdGlyph.copy, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LdSettingRow(
            label: l10n.shareLinkAllowDownload,
            glyph: LdGlyph.download,
            trailing: LdSwitch(
              value: share.allowDownload,
              onChanged: (value) async {
                await db.update(share.id, allowDownload: value);
                refresh();
              },
            ),
          ),
          const Divider(height: 1, color: LdColors.strokeOutline),
          LdSettingRow(
            label: l10n.shareLinkExpiry,
            description: share.expires
                ? LdFormat.dateTime(context, share.expiresAt)
                : l10n.neverExpires,
            glyph: LdGlyph.clock,
            onTap: () async {
              final choice = await _pickExpiry(context, anchorOf(context));
              if (choice == null) return;
              await db.update(share.id, expiresAt: choice);
              refresh();
            },
          ),
          const Divider(height: 1, color: LdColors.strokeOutline),
          LdSettingRow(
            label: l10n.shareLinkPassword,
            description: share.passwordProtected
                ? l10n.shareLinkPassword
                : l10n.shareLinkNoPassword,
            glyph: LdGlyph.lock,
            onTap: () async {
              final password = await _pickPassword(context);
              if (password == null) return;
              await db.update(share.id, password: password);
              refresh();
            },
          ),
          const SizedBox(height: 14),
          LdButton.destructive(
            label: l10n.shareRevoke,
            compact: true,
            onPressed: () async {
              await db.revoke(share.id);
              refresh();
              if (context.mounted) LdToast.success(context, l10n.shareRevoked);
            },
          ),
        ],
      ),
    );
  }

  Future<int?> _pickExpiry(BuildContext context, Offset anchor) async {
    final l10n = L10n.of(context);
    final now = DateTime.now();
    final choice = await LdContextMenu.show(
      context,
      title: l10n.linkExpiration,
      anchor: anchor == Offset.zero ? null : anchor,
      actions: <LdMenuAction>[
        LdMenuAction(
          id: 'never',
          label: l10n.neverExpires,
          glyph: LdGlyph.refresh,
        ),
        LdMenuAction(id: 'day', label: l10n.shareExpiryDay, glyph: LdGlyph.clock),
        LdMenuAction(
          id: 'week',
          label: l10n.shareExpiryWeek,
          glyph: LdGlyph.clock,
        ),
        LdMenuAction(
          id: 'month',
          label: l10n.shareExpiryMonth,
          glyph: LdGlyph.clock,
        ),
        LdMenuAction(
          id: 'custom',
          label: l10n.shareExpiryCustom,
          glyph: LdGlyph.grid,
        ),
      ],
    );
    if (choice == null || !context.mounted) return null;
    return switch (choice) {
      'never' => 0,
      'day' => now.add(const Duration(days: 1)).millisecondsSinceEpoch,
      'week' => now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      'month' => now.add(const Duration(days: 30)).millisecondsSinceEpoch,
      'custom' => (await LdDatePicker.show(
          context,
          title: l10n.linkExpiration,
          confirmLabel: l10n.actionSave,
          cancelLabel: l10n.actionCancel,
        ))
          ?.millisecondsSinceEpoch,
      _ => null,
    };
  }

  Future<String?> _pickPassword(BuildContext context) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final result = await LdBottomSheet.show<String>(
      context,
      title: l10n.shareLinkPassword,
      scrollable: false,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LdTextField(
            controller: controller,
            label: l10n.shareLinkPassword,
            hint: l10n.shareLinkPasswordHint,
            obscure: true,
            autofocus: true,
            helperText: l10n.passwordTooShort,
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: LdButton.secondary(
                  label: l10n.shareLinkNoPassword,
                  onPressed: () => Navigator.of(sheetContext).pop(''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LdButton(
                  label: l10n.actionSave,
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

/// Shows the local network explanation once, on the platform that needs it.
///
/// A no is a real answer: the picker keeps working as the plain list it always
/// was, and nothing asks again.
Future<void> _explainLocalNetwork(BuildContext context, WidgetRef ref) async {
  final permission = ref.read(nearbyPermissionProvider.notifier);
  if (!await permission.needsExplaining() || !context.mounted) return;

  final l10n = L10n.of(context);
  final allow = await LdBottomSheet.confirm(
    context,
    title: l10n.nearbyWhyTitle,
    message: l10n.nearbyWhyBody,
    confirmLabel: l10n.nearbyAllow,
    cancelLabel: l10n.notificationsNotNow,
  );

  if (allow) {
    await permission.allow();
    return;
  }
  await permission.decline();
}
