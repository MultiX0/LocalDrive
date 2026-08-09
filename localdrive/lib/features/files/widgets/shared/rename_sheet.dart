import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import 'package:path/path.dart' as p;

import '../../../../imports.dart';
import '../../../upload/controller/transfer_controller.dart';
import '../../../upload/widgets/duplicate_sheet.dart';
import '../../../storage/providers/storage_providers.dart';
import '../../controller/files_controller.dart';
import '../../models/node_model.dart';

/// Rename, as a branded sheet rather than a dialog.
Future<void> showRenameSheet(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
) async {
  final l10n = L10n.of(context);
  final controller = TextEditingController(text: node.name);

  final name = await LdBottomSheet.show<String>(
    context,
    title: l10n.actionRename,
    scrollable: false,
    builder: (sheetContext) => _NameForm(
      controller: controller,
      label: l10n.renameTo,
      submitLabel: l10n.actionSave,
      cancelLabel: l10n.actionCancel,
    ),
  );
  controller.dispose();

  if (name == null || name.trim().isEmpty || !context.mounted) return;
  await ref.read(filesControllerProvider.notifier).rename(node, name.trim());
}

/// New folder. When more than one library exists, this adds exactly one field:
/// which one it lives in, each option showing its free space so the choice is
/// informed. A folder inside another folder skips this and inherits.
Future<void> showNewFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required String parentId,
}) async {
  final l10n = L10n.of(context);
  final controller = TextEditingController();

  final result = await LdBottomSheet.show<({String name, String libraryId})>(
    context,
    title: l10n.newFolder,
    scrollable: true,
    builder: (sheetContext) => _NewFolderForm(
      controller: controller,
      atTopLevel: parentId.isEmpty || parentId == Api.rootParent,
    ),
  );
  controller.dispose();

  if (result == null || result.name.trim().isEmpty || !context.mounted) return;
  await ref.read(filesControllerProvider.notifier).createFolder(
        name: result.name.trim(),
        parentId: parentId,
        libraryId: result.libraryId,
      );
  if (context.mounted) LdToast.success(context, l10n.newFolder);
}

class _NameForm extends HookWidget {
  const _NameForm({
    required this.controller,
    required this.label,
    required this.submitLabel,
    required this.cancelLabel,
  });

  final TextEditingController controller;
  final String label;
  final String submitLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final text = useValueListenable(controller);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // no hint on purpose: this form opens with the current name already in
        // it, so a hint would never be on screen to read
        LdTextField(
          controller: controller,
          label: label,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: LdButton.secondary(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LdButton(
                label: submitLabel,
                onPressed: text.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(controller.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewFolderForm extends HookConsumerWidget {
  const _NewFolderForm({required this.controller, required this.atTopLevel});

  final TextEditingController controller;
  final bool atTopLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final text = useValueListenable(controller);
    final chosenLibrary = useState<String>('');
    final libraries = atTopLevel
        ? ref.watch(librariesProvider)
        : const AsyncValue<LibrarySummary>.loading();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LdTextField(
          controller: controller,
          label: l10n.folderNameLabel,
          hint: l10n.folderNameHint,
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        if (atTopLevel)
          libraries.maybeWhen(
            data: (summary) {
              // one library means there is no choice worth asking about
              if (summary.libraries.length < 2) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.chooseLibrary,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    for (final library in summary.libraries)
                      LdRadioRow(
                        label: library.name,
                        subtitle: library.statsKnown
                            ? l10n.libraryFreeSpace(
                                LdFormat.bytes(context, library.freeBytes),
                              )
                            : l10n.storageOffline,
                        selected: chosenLibrary.value.isEmpty
                            ? library.isDefault
                            : chosenLibrary.value == library.id,
                        onTap: () => chosenLibrary.value = library.id,
                      ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: LdButton.secondary(
                label: l10n.actionCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LdButton(
                label: l10n.actionSave,
                onPressed: text.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          (
                            name: controller.text,
                            libraryId: chosenLibrary.value,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


/// Picks files and hands them to the durable transfer queue. Shared, because
/// the phone's create sheet, the desktop top bar, and the drop zone all end up
/// in the same place.
Future<void> pickAndUpload(
  BuildContext context,
  WidgetRef ref,
  String parentId,
) async {
  final l10n = L10n.of(context);

  // withData on the web only: a browser has no path to give, so the picker has
  // to read the contents up front. Asking for data on desktop or mobile would
  // load the whole file into memory for no reason, when a path is right there.
  final picked = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: kIsWeb,
  );
  if (picked == null || picked.files.isEmpty) return;
  if (!context.mounted) return;

  final transfers = ref.read(transferControllerProvider.notifier);

  if (kIsWeb) {
    final files = <({String name, Uint8List bytes})>[
      for (final file in picked.files)
        if (file.bytes != null) (name: file.name, bytes: file.bytes!),
    ];
    if (files.isEmpty) return;
    final decisions = await resolveDuplicates(
      context,
      ref,
      names: <String>[for (final file in files) file.name],
      parentId: parentId,
    );
    if (decisions == null) return;
    final queued = await enqueueByDecision(
      transfers: transfers,
      decisions: decisions,
      parentId: parentId,
      bytes: files,
    );
    if (queued == 0) return;
  } else {
    final paths = picked.files
        .map((file) => file.path)
        .where((path) => path != null && path.isNotEmpty)
        .cast<String>()
        .toList();
    if (paths.isEmpty) return;
    final decisions = await resolveDuplicates(
      context,
      ref,
      names: <String>[for (final path in paths) p.basename(path)],
      parentId: parentId,
    );
    if (decisions == null) return;
    final queued = await enqueueByDecision(
      transfers: transfers,
      decisions: decisions,
      parentId: parentId,
      paths: paths,
    );
    if (queued == 0) return;
  }

  if (context.mounted) LdToast.success(context, l10n.upload);
}

/// Queues each file the way its decision says, skipping the ones that were
/// declined and pointing a replacement at the node it replaces.
///
/// Each replacement goes on its own, because a node id belongs to exactly one
/// file. Everything kept can go in one batch.
Future<int> enqueueByDecision({
  required TransferController transfers,
  required List<UploadDecision> decisions,
  required String parentId,
  List<String>? paths,
  List<({String name, Uint8List bytes})>? bytes,
}) async {
  var queued = 0;
  final keeping = <int>[];

  for (final decision in decisions) {
    switch (decision.choice) {
      case DuplicateChoice.skip:
        continue;
      case DuplicateChoice.keepBoth:
        keeping.add(decision.index);
      case DuplicateChoice.replace:
        queued += paths != null
            ? await transfers.enqueueUploads(
                paths: <String>[paths[decision.index]],
                parentId: parentId,
                nodeId: decision.replaceNodeId,
              )
            : await transfers.enqueueUploadBytes(
                files: <({String name, Uint8List bytes})>[
                  bytes![decision.index],
                ],
                parentId: parentId,
                nodeId: decision.replaceNodeId,
              );
    }
  }

  if (keeping.isNotEmpty) {
    queued += paths != null
        ? await transfers.enqueueUploads(
            paths: <String>[for (final i in keeping) paths[i]],
            parentId: parentId,
          )
        : await transfers.enqueueUploadBytes(
            files: <({String name, Uint8List bytes})>[
              for (final i in keeping) bytes![i],
            ],
            parentId: parentId,
          );
  }
  return queued;
}
