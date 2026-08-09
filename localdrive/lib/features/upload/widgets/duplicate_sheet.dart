import '../../../imports.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';

/// What to do about a file whose name is already taken in the destination.
enum DuplicateChoice {
  /// upload it anyway. The server appends " (2)" so both survive
  keepBoth,

  /// upload it as a new version of the file already there, which keeps the
  /// old bytes in version history rather than throwing them away
  replace,

  /// leave the one already there alone and do not upload
  skip,
}

/// One incoming file and what was decided about it.
class UploadDecision {
  const UploadDecision({
    required this.index,
    required this.choice,
    this.replaceNodeId = '',
  });

  /// position in the list that was handed to [resolveDuplicates]
  final int index;
  final DuplicateChoice choice;

  /// the node to add a version to, set only when [choice] is replace
  final String replaceNodeId;
}

/// Asks about every incoming name that is already taken in the destination.
///
/// Uploading on top of an existing name used to be silent: the server appended
/// " (2)" and the person found out later, looking at two copies of the same
/// photo and unable to tell which was which. The rename is still the right
/// default, but it is a decision, and a decision belongs to whoever is holding
/// the files.
///
/// Returns one decision per incoming file, or null if the whole upload was
/// cancelled. A destination that cannot be read is not treated as a clash:
/// failing to check is not a reason to block an upload, and the server still
/// renames rather than overwrites.
Future<List<UploadDecision>?> resolveDuplicates(
  BuildContext context,
  WidgetRef ref, {
  required List<String> names,
  required String parentId,
}) async {
  final keepAll = <UploadDecision>[
    for (var i = 0; i < names.length; i++)
      UploadDecision(index: i, choice: DuplicateChoice.keepBoth),
  ];
  if (names.isEmpty) return keepAll;

  final List<NodeModel> siblings;
  try {
    siblings = await ref.read(filesDbProvider).list(parentId: parentId);
  } on Object {
    return keepAll;
  }

  // names compare without case, the same way the server decides a clash, so
  // Photo.PNG and photo.png are recognised as the same name
  final existing = <String, NodeModel>{
    for (final node in siblings)
      if (!node.isFolder) node.name.toLowerCase(): node,
  };

  final clashes = <int>[
    for (var i = 0; i < names.length; i++)
      if (existing.containsKey(names[i].toLowerCase())) i,
  ];
  if (clashes.isEmpty) return keepAll;
  if (!context.mounted) return null;

  final choice = await _ask(
    context,
    first: names[clashes.first],
    total: clashes.length,
  );
  if (choice == null) return null;

  return <UploadDecision>[
    for (var i = 0; i < names.length; i++)
      if (!clashes.contains(i))
        UploadDecision(index: i, choice: DuplicateChoice.keepBoth)
      else
        UploadDecision(
          index: i,
          choice: choice,
          replaceNodeId: choice == DuplicateChoice.replace
              ? existing[names[i].toLowerCase()]!.id
              : '',
        ),
  ];
}

/// One question covering every clash in the batch.
///
/// Asking once per file would mean twelve identical sheets for twelve photos
/// dropped at once, which is how a helpful question turns into an obstacle.
Future<DuplicateChoice?> _ask(
  BuildContext context, {
  required String first,
  required int total,
}) async {
  final l10n = L10n.of(context);
  final choice = await LdContextMenu.show(
    context,
    title: total == 1 ? l10n.uploadClashTitle : l10n.uploadClashTitleMany,
    subtitle: total == 1
        ? l10n.uploadClashBody(first)
        : l10n.uploadClashBodyMany(LdFormat.count(context, total)),
    actions: <LdMenuAction>[
      LdMenuAction(
        id: 'keep',
        label: l10n.uploadClashKeepBoth,
        glyph: LdGlyph.copy,
      ),
      LdMenuAction(
        id: 'replace',
        label: l10n.uploadClashReplace,
        glyph: LdGlyph.refresh,
      ),
      LdMenuAction(
        id: 'skip',
        label: l10n.uploadClashSkip,
        glyph: LdGlyph.close,
      ),
    ],
  );

  return switch (choice) {
    'keep' => DuplicateChoice.keepBoth,
    'replace' => DuplicateChoice.replace,
    'skip' => DuplicateChoice.skip,
    _ => null,
  };
}
