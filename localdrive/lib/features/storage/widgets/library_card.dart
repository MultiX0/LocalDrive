import '../../../imports.dart';
import '../providers/storage_providers.dart';

/// One library, with its own used and free numbers, its default marker, and
/// the eject action when it is a removable drive.
class LibraryCard extends ConsumerWidget {
  const LibraryCard({super.key, required this.library, required this.isAdmin});

  final LibraryModel library;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final online = library.isOnline;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(
          color: online ? LdColors.strokeOutline : LdColors.accentWarning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              LdIcon(
                library.isPooled ? LdGlyph.grid : LdGlyph.drive,
                size: 20,
                color: online
                    ? LdColors.foregroundPrimary
                    : LdColors.accentWarning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      library.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (!online) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        l10n.storageOffline,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: LdColors.accentWarning,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (library.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: LdColors.wash(LdColors.accentPrimary),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    l10n.storageDefault,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: LdColors.accentPrimary,
                          letterSpacing: 0,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // bytesUsed is everything on this drive, every account included, so
          // it is an admin figure. What a member needs from this card is where
          // the drive is and whether there is room on it, and free space
          // answers both without saying how much anyone else is keeping
          LdUsageBar(
            usedBytes: isAdmin ? library.bytesUsed : 0,
            totalBytes: library.statsKnown ? library.totalBytes : 0,
            usedLabel: isAdmin ? LdFormat.bytes(context, library.bytesUsed) : '',
            freeLabel: library.statsKnown
                ? l10n.libraryFreeSpace(
                    LdFormat.bytes(context, library.freeBytes),
                  )
                : l10n.storageOffline,
          ),
          if (isAdmin) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                if (!library.isDefault && online)
                  Expanded(
                    child: LdButton.secondary(
                      label: l10n.storageSetDefault,
                      compact: true,
                      onPressed: () async {
                        await ref
                            .read(storageDbProvider)
                            .setDefault(library.id);
                        ref.invalidate(librariesProvider);
                      },
                    ),
                  ),
                if (!library.isDefault && online && library.isExternal)
                  const SizedBox(width: 10),
                if (library.isExternal && online)
                  Expanded(
                    child: LdButton.secondary(
                      label: l10n.storageEject,
                      glyph: LdGlyph.eject,
                      compact: true,
                      onPressed: () async {
                        final message = await ref
                            .read(storageDbProvider)
                            .eject(library.id);
                        ref.invalidate(librariesProvider);
                        if (context.mounted) {
                          LdToast.success(
                            context,
                            message.isEmpty
                                ? l10n.storageSafeToUnplug
                                : message,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
