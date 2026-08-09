import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';

import '../../../../imports.dart';
import '../../../upload/controller/transfer_controller.dart';
import '../../../upload/controller/folder_drop.dart';
import '../../../upload/widgets/duplicate_sheet.dart';
import '../../providers/files_providers.dart';
import 'folder_drop_targets.dart';
import '../shared/rename_sheet.dart';

/// The visible drag and drop target on desktop and web. It is deliberately
/// visible only while something is being dragged, so it does not sit on the
/// screen as decoration the rest of the time.
class FilesDropZone extends ConsumerStatefulWidget {
  const FilesDropZone({
    super.key,
    required this.child,
    required this.folderId,
  });

  final Widget child;
  final String folderId;

  @override
  ConsumerState<FilesDropZone> createState() => _FilesDropZoneState();
}

class _FilesDropZoneState extends ConsumerState<FilesDropZone> {
  bool _dragging = false;


  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      // which folder the pointer is over, updated as it moves, so the tile
      // under it lights up exactly the way an in app drag makes it light up
      onDragUpdated: (details) {
        final over = FolderDropTargets.instance.at(details.globalPosition);
        if (ref.read(osDropTargetProvider) != over) {
          ref.read(osDropTargetProvider.notifier).state = over;
        }
      },
      onDragExited: (_) {
        ref.read(osDropTargetProvider.notifier).state = '';
        setState(() => _dragging = false);
      },
      onDragDone: (details) async {
        setState(() => _dragging = false);
        if (details.files.isEmpty) return;

        // Released over a folder tile means into that folder, which is what
        // dropping onto a folder means everywhere else. Released over open
        // space means the folder being viewed.
        final overFolder =
            FolderDropTargets.instance.at(details.globalPosition);
        ref.read(osDropTargetProvider.notifier).state = '';
        final destination =
            overFolder.isEmpty ? widget.folderId : overFolder;
        // the messages are resolved before the await, so nothing reads a
        // context that may be gone by the time the queue accepts the files
        final queued = l10n.upload;
        final failed = l10n.errorUnexpectedTitle;
        final messenger = context.mounted ? context : null;

        final transfers = ref.read(transferControllerProvider.notifier);
        final names = details.files.map((file) => file.name).toList();

        if (messenger == null || !messenger.mounted) return;

        // A browser hands a dropped folder over as its own object rather than
        // a path, with the files inside it nested underneath rather than
        // alongside it. Nothing here walks that nesting, so uploading it as
        // is would silently read zero bytes and report success on an empty
        // file named after the folder.
        if (kIsWeb && details.files.any((file) => file is DropItemDirectory)) {
          LdToast.error(messenger, l10n.errorFoldersNotSupportedWeb);
          return;
        }

        // a folder drop makes its own folders, so a name clash question about
        // the folder itself would be asking about the wrong thing
        final droppingFolders = !kIsWeb &&
            details.files.any(
              (file) =>
                  FileSystemEntity.typeSync(file.path, followLinks: false) ==
                  FileSystemEntityType.directory,
            );
        final decisions = droppingFolders
            ? const <UploadDecision>[]
            : await resolveDuplicates(
                messenger,
                ref,
                names: names,
                parentId: destination,
              );
        if (decisions == null) return;

        final int accepted;
        if (kIsWeb) {
          // a page has no filesystem, so the drop hands over an object to read
          // rather than somewhere to read from. Asking dart:io to open the
          // path a browser reports gets nothing, which is why a drop used to
          // land here and quietly do nothing at all
          final files = <({String name, Uint8List bytes})>[];
          for (final file in details.files) {
            files.add((name: file.name, bytes: await file.readAsBytes()));
          }
          accepted = await enqueueByDecision(
            transfers: transfers,
            decisions: decisions,
            parentId: destination,
            bytes: files,
          );
        } else {
          // A folder arrives as one path. Walking it here is what turns a
          // dropped folder into the same folder on the server with its tree
          // intact, rather than an error or a pile of loose files.
          final paths = details.files.map((file) => file.path).toList();
          final plan = await planDrop(paths);
          final nested = plan.folders.isNotEmpty;

          accepted = nested
              ? await runDropPlan(
                  plan: plan,
                  db: ref.read(filesDbProvider),
                  transfers: transfers,
                  parentId: destination,
                )
              : await enqueueByDecision(
                  transfers: transfers,
                  decisions: decisions,
                  parentId: destination,
                  paths: paths,
                );
        }

        if (!mounted || !messenger.mounted) return;
        if (accepted == 0 && decisions.isNotEmpty) {
          // everything was skipped on purpose, which is not a failure
          final skipped = decisions.every(
            (d) => d.choice == DuplicateChoice.skip,
          );
          if (skipped) return;
        }
        if (accepted == 0) {
          LdToast.error(messenger, failed);
          return;
        }
        LdToast.success(messenger, queued);
      },
      child: Stack(
        children: <Widget>[
          widget.child,
          // The whole surface, not a margin inset panel. A drop target that
          // covers everything says "let go anywhere" without having to be
          // read, which is the entire job of this overlay.
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: LdMotion.tapFade,
                  opacity: 1,
                  child: Container(
                    color: LdColors.wash(LdColors.accentPrimary, 0.10),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: LdColors.backgroundElevated,
                          borderRadius: LdRadii.cardRadius,
                          border: Border.all(
                            color: LdColors.accentPrimary,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const LdIcon(
                              LdGlyph.upload,
                              size: 44,
                              color: LdColors.accentPrimary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.dropToUpload,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              kIsWeb
                                  ? l10n.dropToUploadHintWeb
                                  : l10n.dropToUploadHint,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: LdColors.foregroundSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
