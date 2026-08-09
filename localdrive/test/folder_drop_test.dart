import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/features/upload/controller/folder_drop.dart';

/// Dropping a folder has to arrive as that folder, with its shape intact.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ld-drop-');
    // trip/
    //   note.txt
    //   photos/
    //     one.jpg
    //     raw/two.dng
    final trip = Directory('${root.path}/trip')..createSync();
    File('${trip.path}/note.txt').writeAsStringSync('hi');
    final photos = Directory('${trip.path}/photos')..createSync();
    File('${photos.path}/one.jpg').writeAsStringSync('a');
    final raw = Directory('${photos.path}/raw')..createSync();
    File('${raw.path}/two.dng').writeAsStringSync('b');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a loose file has no folders and no path above it', () async {
    final loose = File('${root.path}/loose.txt')..writeAsStringSync('x');
    final plan = await planDrop(<String>[loose.path]);

    expect(plan.folders, isEmpty);
    expect(plan.fileCount, 1);
    expect(plan.files.single.relativeDir, isEmpty);
  });

  test('a dropped folder keeps every file at the depth it was found', () async {
    final plan = await planDrop(<String>['${root.path}/trip']);

    expect(plan.fileCount, 3);

    Iterable<String> dirOf(String name) => plan.files
        .firstWhere((f) => f.path.endsWith(name))
        .relativeDir;

    expect(dirOf('note.txt'), <String>['trip']);
    expect(dirOf('one.jpg'), <String>['trip', 'photos']);
    expect(dirOf('two.dng'), <String>['trip', 'photos', 'raw']);
  });

  test('folders come out shallowest first, so a parent always exists', () async {
    final plan = await planDrop(<String>['${root.path}/trip']);

    expect(
      plan.folders.map((f) => f.join('/')).toList(),
      <String>['trip', 'trip/photos', 'trip/photos/raw'],
    );

    // the ordering guarantee stated as the rule it protects
    final made = <String>{''};
    for (final folder in plan.folders) {
      final parent = folder.sublist(0, folder.length - 1).join('/');
      expect(
        made.contains(parent),
        isTrue,
        reason: '${folder.join('/')} would be created before its parent',
      );
      made.add(folder.join('/'));
    }
  });

  test('several things dropped at once are all planned together', () async {
    final loose = File('${root.path}/loose.txt')..writeAsStringSync('x');
    final plan = await planDrop(<String>[loose.path, '${root.path}/trip']);

    expect(plan.fileCount, 4);
    expect(plan.folders.length, 3);
  });

  test('an empty folder is still created, because it was dropped', () async {
    Directory('${root.path}/empty').createSync();
    final plan = await planDrop(<String>['${root.path}/empty']);

    expect(plan.fileCount, 0);
    expect(plan.folders, <List<String>>[
      <String>['empty'],
    ]);
  });
}
