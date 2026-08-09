import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/enums/file_category.dart';
import 'package:localdrive/features/files/models/node_model.dart';
import 'package:localdrive/features/gallery/providers/gallery_providers.dart';

NodeModel _photo(
  String id, {
  int taken = 0,
  int created = 0,
  int updated = 0,
  int width = 0,
  int height = 0,
}) =>
    NodeModel(
      id: id,
      name: '$id.jpg',
      isFolder: false,
      category: FileCategory.image,
      libraryId: 'lib',
      imageWidth: width,
      imageHeight: height,
      takenAt: taken,
      createdAt: created,
      updatedAt: updated,
    );

/// Stands in for the localized heading, so grouping can be tested without a
/// widget tree. The real one produces month and day names.
String _label(DateTime moment, GalleryGrouping grouping) => switch (grouping) {
      GalleryGrouping.day => '${moment.year}-${moment.month}-${moment.day}',
      GalleryGrouping.month => '${moment.year}-${moment.month}',
      GalleryGrouping.year => '${moment.year}',
      GalleryGrouping.none => '',
    };

int _at(int year, int month, int day) =>
    DateTime(year, month, day, 12).millisecondsSinceEpoch;

void main() {
  group('what a photo says about itself', () {
    test('capture time wins over upload time when there is one', () {
      final photo = _photo('a', taken: _at(2019, 7, 14), created: _at(2026, 1, 1));
      expect(photo.capturedAt, _at(2019, 7, 14));
    });

    test('with no capture time it falls back to when it was uploaded', () {
      // without the fallback every screenshot and download would pile up at
      // one end of a gallery sorted by capture time
      final shot = _photo('b', created: _at(2026, 1, 1));
      expect(shot.capturedAt, _at(2026, 1, 1));
    });

    test('a picture with no recorded size is laid out square', () {
      expect(_photo('c').aspectRatio, 1);
    });

    test('a recorded size becomes the tile shape', () {
      expect(_photo('d', width: 400, height: 300).aspectRatio, closeTo(4 / 3, 0.001));
    });
  });

  group('grouping the timeline', () {
    test('runs are split on the field the list is actually sorted by', () {
      final nodes = <NodeModel>[
        _photo('a', taken: _at(2026, 3, 4)),
        _photo('b', taken: _at(2026, 3, 20)),
        _photo('c', taken: _at(2026, 2, 1)),
      ];

      final sections = groupGallery(
        nodes,
        sort: GallerySort.taken,
        grouping: GalleryGrouping.month,
        label: _label,
      );

      expect(sections.length, 2);
      expect(sections[0].label, '2026-3');
      expect(sections[0].items.map((n) => n.id), <String>['a', 'b']);
      expect(sections[1].label, '2026-2');
      expect(sections[1].items.map((n) => n.id), <String>['c']);
    });

    test('grouping by day splits what grouping by month keeps together', () {
      final nodes = <NodeModel>[
        _photo('a', taken: _at(2026, 3, 4)),
        _photo('b', taken: _at(2026, 3, 20)),
      ];

      expect(
        groupGallery(
          nodes,
          sort: GallerySort.taken,
          grouping: GalleryGrouping.day,
          label: _label,
        ).length,
        2,
      );
      expect(
        groupGallery(
          nodes,
          sort: GallerySort.taken,
          grouping: GalleryGrouping.month,
          label: _label,
        ).length,
        1,
      );
    });

    test('sorting by name produces one unlabelled run, not date headings', () {
      // headings taken from a date over a list ordered by name would not match
      // the order underneath them, which reads as a bug
      final sections = groupGallery(
        <NodeModel>[
          _photo('a', taken: _at(2026, 3, 4)),
          _photo('b', taken: _at(2020, 1, 1)),
        ],
        sort: GallerySort.name,
        grouping: GalleryGrouping.month,
        label: _label,
      );

      expect(sections.length, 1);
      expect(sections.single.label, '');
      expect(sections.single.items.length, 2);
    });

    test('grouping off keeps everything in one run', () {
      final sections = groupGallery(
        <NodeModel>[_photo('a', taken: _at(2026, 3, 4))],
        sort: GallerySort.taken,
        grouping: GalleryGrouping.none,
        label: _label,
      );
      expect(sections.single.label, '');
    });

    test('grouping by date added uses upload time, not capture time', () {
      // the same two photos land in one month or two depending on which field
      // the list is ordered by, and the headings have to agree with the order
      final nodes = <NodeModel>[
        _photo('a', taken: _at(2019, 7, 1), created: _at(2026, 3, 1)),
        _photo('b', taken: _at(2021, 2, 1), created: _at(2026, 3, 2)),
      ];

      final byAdded = groupGallery(
        nodes,
        sort: GallerySort.added,
        grouping: GalleryGrouping.month,
        label: _label,
      );
      expect(byAdded.length, 1);

      final byTaken = groupGallery(
        nodes,
        sort: GallerySort.taken,
        grouping: GalleryGrouping.month,
        label: _label,
      );
      expect(byTaken.length, 2);
    });

    test('an empty gallery produces no sections at all', () {
      expect(
        groupGallery(
          const <NodeModel>[],
          sort: GallerySort.taken,
          grouping: GalleryGrouping.month,
          label: _label,
        ),
        isEmpty,
      );
    });
  });

  group('the ordering choices', () {
    test('a timeline defaults to newest first, a name does not', () {
      expect(GallerySort.taken.defaultDescending, isTrue);
      expect(GallerySort.added.defaultDescending, isTrue);
      // nobody wants their photos alphabetised backwards by default
      expect(GallerySort.name.defaultDescending, isFalse);
    });

    test('only a time based order can carry date headings', () {
      expect(GallerySort.taken.groupable, isTrue);
      expect(GallerySort.modified.groupable, isTrue);
      expect(GallerySort.size.groupable, isFalse);
      expect(GallerySort.name.groupable, isFalse);
    });
  });
}
