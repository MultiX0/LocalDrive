import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';

/// Who is signed in, and how much of their quota is gone.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Row(
        children: <Widget>[
          LdAvatar(name: user.displayName, seed: user.avatarSeed, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  user.isAdmin ? l10n.roleAdmin : l10n.roleMember,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (user.hasQuota) ...<Widget>[
                  const SizedBox(height: 10),
                  LdProgressBar(value: user.quotaFraction, height: 5),
                  const SizedBox(height: 6),
                  Text(
                    l10n.storageUsedOf(
                      LdFormat.bytes(context, user.quotaBytesUsed),
                      LdFormat.bytes(context, user.quotaBytes),
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
