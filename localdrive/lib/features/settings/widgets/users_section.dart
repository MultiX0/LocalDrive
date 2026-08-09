import '../../../imports.dart';
import '../../auth/models/user_model.dart';

final _usersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final json = await ref.watch(apiClientProvider).get(Api.adminUsers);
  return (json['users'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(UserModel.fromJson)
      .toList(growable: false);
});

final _invitesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final json = await ref.watch(apiClientProvider).get(Api.invites);
    return (json['invites'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  },
);

/// Users and invites. Getting an account is not open by default: an admin
/// creates an invite, sends the code however they already talk to that person,
/// and the invitee picks their own username and password on their own device.
class UsersSection extends ConsumerWidget {
  const UsersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final users = ref.watch(_usersProvider);

    return LdRefresh(
      onRefresh: () async {
        ref.invalidate(_usersProvider);
        ref.invalidate(_invitesProvider);
        await ref.read(_usersProvider.future);
      },
      child: LdContentPane(
        maxWidth: LdContentPane.list,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            16,
            context.pagePadding,
            120,
          ),
          children: <Widget>[
            // On a phone the invite button is the full width of the screen,
            // because a thumb wants a big target. Stretched across a desktop it
            // reads as a banner rather than a button, so there it sits at its
            // own size on the right, above the list it adds to.
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.settingsUsers,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Builder(
                  builder: (context) => LdButton(
                    label: l10n.usersInviteSomeone,
                    glyph: LdGlyph.qr,
                    compact: true,
                    expand: false,
                    onPressed: () => _invite(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LdAsync<List<UserModel>>(
              value: users,
              errorCopy: LdFormat.errorCopy(context),
              onRetry: () => ref.invalidate(_usersProvider),
              loading: const LdListSkeleton(rows: 3, padding: EdgeInsets.zero),
              isEmpty: (list) => list.isEmpty,
              empty: () => LdEmptyState(
                title: l10n.emptyUsersTitle,
                message: l10n.emptyUsersBody,
                glyph: LdGlyph.people,
                compact: true,
              ),
              data: (list) => Column(
                children: <Widget>[
                  for (final user in list)
                    LdSettingRow(
                      label: user.displayName,
                      // how much each account is storing, which is what an admin
                      // needs to answer "who filled the disk". It is a total
                      // only: an admin can see the size of what someone keeps
                      // and never the files themselves.
                      description: <String>[
                        user.isAdmin ? l10n.roleAdmin : l10n.roleMember,
                        user.hasQuota
                            ? l10n.storageUsedOf(
                                LdFormat.bytes(context, user.quotaBytesUsed),
                                LdFormat.bytes(context, user.quotaBytes),
                              )
                            : l10n.sidebarStorageUsed(
                                LdFormat.bytes(context, user.quotaBytesUsed),
                              ),
                      ].join('  ·  '),
                      trailing: LdAvatar(
                        name: user.displayName,
                        seed: user.avatarSeed,
                        size: 34,
                      ),
                      onTap: () =>
                          _manage(context, ref, user, anchorOf(context)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final label = TextEditingController();

    final created = await LdBottomSheet.show<Map<String, dynamic>>(
      context,
      title: l10n.usersInviteSomeone,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, sheetRef, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LdTextField(
              controller: label,
              label: l10n.usersInviteLabel,
              hint: l10n.usersInviteHint,
              autofocus: true,
            ),
            const SizedBox(height: 20),
            LdButton(
              label: l10n.invite,
              onPressed: () async {
                final json = await sheetRef
                    .read(apiClientProvider)
                    .post(
                      Api.invites,
                      body: <String, dynamic>{'label': label.text.trim()},
                    );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(json);
                }
              },
            ),
          ],
        ),
      ),
    );
    label.dispose();
    if (created == null || !context.mounted) return;

    ref.invalidate(_invitesProvider);
    await LdBottomSheet.show<void>(
      context,
      title: l10n.invite,
      subtitle: l10n.usersInviteCreated,
      builder: (sheetContext) => LdInviteCard(
        code: created['code'] as String? ?? '',
        link: ref.read(apiClientProvider).publicLink(
              created['link'] as String? ?? '',
            ),
        copyCodeLabel: l10n.actionCopyCode,
        copyLinkLabel: l10n.actionCopyLink,
        copiedMessage: l10n.actionCopied,
      ),
    );
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    Offset anchor,
  ) async {
    final l10n = L10n.of(context);
    final choice = await LdContextMenu.show(
      context,
      title: user.displayName,
      anchor: anchor == Offset.zero ? null : anchor,
      actions: <LdMenuAction>[
        LdMenuAction(
          id: 'reset',
          label: l10n.usersResetPassword,
          glyph: LdGlyph.lock,
        ),
        LdMenuAction(
          id: 'role',
          label: user.isAdmin ? l10n.usersMakeMember : l10n.usersMakeAdmin,
          glyph: LdGlyph.person,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;

    final api = ref.read(apiClientProvider);
    if (choice == 'reset') {
      final json = await api.post(Api.resetPassword(user.id));
      if (!context.mounted) return;
      await LdBottomSheet.show<void>(
        context,
        title: l10n.usersTemporaryPassword,
        subtitle: l10n.usersTemporaryPasswordNote,
        scrollable: false,
        builder: (sheetContext) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LdColors.backgroundPrimary,
            borderRadius: LdRadii.fieldRadius,
            border: Border.all(color: LdColors.strokeOutline),
          ),
          child: Center(
            child: SelectableText(
              json['temporary_password'] as String? ?? '',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
        ),
      );
      return;
    }

    await api.patch(
      Api.userRole(user.id),
      body: <String, dynamic>{'role': user.isAdmin ? 'member' : 'admin'},
    );
    ref.invalidate(_usersProvider);
  }
}
