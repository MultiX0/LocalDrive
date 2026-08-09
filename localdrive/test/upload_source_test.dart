import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/features/upload/db/upload_source.dart';

void main() {
  final data = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));

  group('BytesUploadSource', () {
    test('reports its length', () async {
      expect(await BytesUploadSource(data).length(), 1000);
    });

    test('returns exactly the requested range', () async {
      final source = BytesUploadSource(data);
      final chunk = await source.readRange(100, 150);
      expect(chunk.length, 50);
      expect(chunk.first, data[100]);
      expect(chunk.last, data[149]);
    });

    test('chunked reads reassemble into the original', () async {
      final source = BytesUploadSource(data);
      final rebuilt = <int>[];
      var offset = 0;
      const chunkSize = 256;
      while (offset < data.length) {
        final end = (offset + chunkSize).clamp(0, data.length);
        rebuilt.addAll(await source.readRange(offset, end));
        offset = end;
      }
      expect(rebuilt, data);
    });

    test('does not claim to survive a restart', () {
      // the queue relies on this to decide whether a half finished upload is
      // worth keeping, so getting it wrong would leave dead rows behind
      expect(BytesUploadSource(data).survivesRestart, isFalse);
    });
  });

  group('FileUploadSource', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ld-upload-test');
      file = File('${dir.path}${Platform.pathSeparator}sample.bin');
      await file.writeAsBytes(data);
    });

    tearDown(() async => dir.delete(recursive: true));

    test('reads the same bytes as the in memory source', () async {
      final fromDisk = FileUploadSource(file.path);
      final fromMemory = BytesUploadSource(data);

      expect(await fromDisk.length(), await fromMemory.length());
      expect(
        await fromDisk.readRange(300, 400),
        await fromMemory.readRange(300, 400),
      );
    });

    test('survives a restart, unlike bytes in memory', () {
      expect(FileUploadSource(file.path).survivesRestart, isTrue);
    });

    test('reports a missing file rather than throwing', () async {
      final missing = FileUploadSource('${dir.path}/not-here.bin');
      expect(await missing.exists(), isFalse);
    });
  });

  group('InMemorySources', () {
    setUp(InMemorySources.instance.clear);

    test('hands back what was stored, then forgets it', () {
      final source = BytesUploadSource(data);
      InMemorySources.instance.put('up-1', source);
      expect(InMemorySources.instance.get('up-1'), same(source));

      InMemorySources.instance.drop('up-1');
      expect(InMemorySources.instance.get('up-1'), isNull);
    });

    test('dropping something that was never there is harmless', () {
      expect(() => InMemorySources.instance.drop('nope'), returnsNormally);
    });
  });
}
