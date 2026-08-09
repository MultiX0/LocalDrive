import 'dart:io';

import 'package:path/path.dart' as p;

import '../../files/db/files_db.dart';
import 'transfer_controller.dart';

/// One file found under a dropped folder, and where it belongs.
class DroppedFile {
  const DroppedFile({required this.path, required this.relativeDir});

  final String path;

  /// the folders between the drop target and this file, outermost first. Empty
  /// when the file was dropped on its own rather than inside a folder
  final List<String> relativeDir;
}

/// What a drop turned out to be once the folders were walked.
class DropPlan {
  const DropPlan({required this.files, required this.folders});

  final List<DroppedFile> files;

  /// every distinct folder path that has to exist, shallowest first, so
  /// creating them in order always has a parent to hang from
  final List<List<String>> folders;

  int get fileCount => files.length;
  bool get isEmpty => files.isEmpty && folders.isEmpty;
}

/// Walks whatever the OS handed over into a flat plan.
///
/// Dropping a folder on Drive uploads the folder, not an error, and that means
/// walking it here: the tus endpoint takes one file at a time and knows nothing
/// about trees. Nested folders keep their shape because each file remembers the
/// path it was found at, and the folders are created before anything is queued
/// so no upload is ever waiting on a parent that does not exist yet.
///
/// Symlinks are not followed. A link pointing back up its own tree would walk
/// forever, and a link pointing outside the folder would quietly upload files
/// from somewhere nobody dropped.
Future<DropPlan> planDrop(List<String> paths) async {
  final files = <DroppedFile>[];
  final folders = <List<String>>[];
  final seen = <String>{};

  Future<void> walk(Directory dir, List<String> prefix) async {
    final here = <String>[...prefix, p.basename(dir.path)];
    final key = here.join('/');
    if (seen.add(key)) folders.add(here);

    final entries = await dir.list(followLinks: false).toList();
    // files first, so a big tree starts transferring before the whole thing
    // has been walked
    for (final entry in entries) {
      if (entry is File) {
        files.add(DroppedFile(path: entry.path, relativeDir: here));
      }
    }
    for (final entry in entries) {
      if (entry is Directory) await walk(entry, here);
    }
  }

  for (final path in paths) {
    if (path.isEmpty) continue;
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await walk(Directory(path), const <String>[]);
      case FileSystemEntityType.file:
        files.add(DroppedFile(path: path, relativeDir: const <String>[]));
      default:
        continue;
    }
  }

  // shallowest first: a child folder can only be made once its parent exists
  folders.sort((a, b) => a.length.compareTo(b.length));
  return DropPlan(files: files, folders: folders);
}

/// Creates the folders a plan needs and queues every file into the right one.
///
/// Returns how many files were queued. Folder creation that fails is not fatal
/// on its own: the rest of the tree still goes, and the listing afterwards
/// shows exactly what landed rather than leaving it to be guessed.
Future<int> runDropPlan({
  required DropPlan plan,
  required FilesDb db,
  required TransferController transfers,
  required String parentId,
}) async {
  // path of folders -> the node id it became on the server
  final made = <String, String>{'': parentId};

  for (final folder in plan.folders) {
    final key = folder.join('/');
    if (made.containsKey(key)) continue;
    final parentKey = folder.sublist(0, folder.length - 1).join('/');
    final parent = made[parentKey];
    if (parent == null) continue;
    try {
      final node = await db.createFolder(name: folder.last, parentId: parent);
      made[key] = node.id;
    } on Object {
      continue;
    }
  }

  // group by destination so each folder's files queue in one call
  final byFolder = <String, List<String>>{};
  for (final file in plan.files) {
    byFolder.putIfAbsent(file.relativeDir.join('/'), () => <String>[])
        .add(file.path);
  }

  var queued = 0;
  for (final entry in byFolder.entries) {
    final destination = made[entry.key];
    if (destination == null) continue;
    queued += await transfers.enqueueUploads(
      paths: entry.value,
      parentId: destination,
    );
  }
  return queued;
}
