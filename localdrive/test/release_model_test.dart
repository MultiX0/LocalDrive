import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/features/about/models/release_model.dart';

void main() {
  group('compareVersions', () {
    test('orders by each component in turn', () {
      expect(ReleaseModel.compareVersions('0.0.2', '0.0.1'), greaterThan(0));
      expect(ReleaseModel.compareVersions('0.1.0', '0.0.9'), greaterThan(0));
      expect(ReleaseModel.compareVersions('1.0.0', '0.9.9'), greaterThan(0));
      expect(ReleaseModel.compareVersions('0.0.1', '0.0.1'), 0);
      expect(ReleaseModel.compareVersions('0.0.1', '0.0.2'), lessThan(0));
    });

    test('compares numerically, not as text', () {
      // the case that makes a string comparison offer a downgrade
      expect(ReleaseModel.compareVersions('0.0.10', '0.0.9'), greaterThan(0));
    });

    test('ignores a v prefix and a build or prerelease suffix', () {
      expect(ReleaseModel.compareVersions('v0.0.2', '0.0.1'), greaterThan(0));
      expect(ReleaseModel.compareVersions('0.0.1+7', '0.0.1'), 0);
      expect(ReleaseModel.compareVersions('0.0.1-rc1', '0.0.1'), 0);
    });

    test('treats an unparsable installed version as older', () {
      // a build from source reports something like "dev", and should still be
      // offered the newest release rather than silently never updating
      expect(ReleaseModel.compareVersions('0.0.1', 'dev'), greaterThan(0));
      expect(ReleaseModel.compareVersions('dev', '0.0.1'), lessThan(0));
    });
  });

  group('fromJson', () {
    final payload = <String, dynamic>{
      'tag_name': '0.0.2',
      'body': '  Fixed a thing.  ',
      'html_url': 'https://github.com/MultiX0/LocalDrive/releases/tag/0.0.2',
      'published_at': '2026-03-14T10:24:00Z',
      'assets': <dynamic>[
        <String, dynamic>{
          'name': 'localdrive-client.apk',
          'browser_download_url': 'https://example.test/localdrive-client.apk',
          'size': 1234,
        },
        <String, dynamic>{
          'name': 'server',
          'browser_download_url': 'https://example.test/server',
          'size': 99,
        },
      ],
    };

    test('picks the asset for this platform and ignores the rest', () {
      final release = ReleaseModel.fromJson(
        payload,
        assetName: 'localdrive-client.apk',
      );
      expect(release.version, '0.0.2');
      expect(release.notes, 'Fixed a thing.');
      expect(release.downloadUrl, 'https://example.test/localdrive-client.apk');
      expect(release.size, 1234);
      expect(release.publishedAt, DateTime.utc(2026, 3, 14, 10, 24));
    });

    test('leaves downloadUrl null when this release has no build for us', () {
      final release = ReleaseModel.fromJson(
        payload,
        assetName: 'localdrive-client-windows.zip',
      );
      expect(release.downloadUrl, isNull);
    });

    test('survives a release with no assets at all', () {
      final release = ReleaseModel.fromJson(
        <String, dynamic>{'tag_name': '0.0.3'},
        assetName: 'localdrive-client.apk',
      );
      expect(release.version, '0.0.3');
      expect(release.downloadUrl, isNull);
      expect(release.notes, isEmpty);
    });
  });
}
