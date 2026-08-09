import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/router/deep_links.dart';

void main() {
  group('parsing a link from outside the app', () {
    test('a public share link resolves the same in all three shapes', () {
      const expected = '/s/abc123';
      expect(parseDeepLink('https://drive.example/s/abc123')?.path, expected);
      expect(parseDeepLink('localdrive://s/abc123')?.path, expected);
      expect(parseDeepLink('localdrive:///s/abc123')?.path, expected);
    });

    test('an https link carries the server it belongs to', () {
      final link = parseDeepLink('https://drive.example:7443/files/n1');
      expect(link, isNotNull);
      expect(link!.path, '/files/n1');
      expect(link.namesServer, isTrue);
      expect(link.serverUrl, contains('drive.example'));
    });

    test('a custom scheme link names no server, because it cannot', () {
      final link = parseDeepLink('localdrive://files/n1');
      expect(link!.path, '/files/n1');
      expect(link.namesServer, isFalse);
    });

    test('an invite and a settings path both survive', () {
      expect(parseDeepLink('localdrive://invite/XYZ')?.path, '/invite/XYZ');
      expect(
        parseDeepLink('https://drive.example/settings/devices')?.path,
        '/settings/devices',
      );
    });

    test('the extension wake up lands on transfers', () {
      expect(parseDeepLink('localdrive://share')?.path, '/transfers');
    });

    test('anything not ours is refused rather than guessed at', () {
      expect(parseDeepLink('https://example.com/pricing'), isNull);
      expect(parseDeepLink('mailto:someone@example.com'), isNull);
      expect(parseDeepLink('localdrive://'), isNull);
      expect(parseDeepLink(''), isNull);
      expect(parseDeepLink('   '), isNull);
    });

    test('files with no id is the root, not a broken route', () {
      expect(parseDeepLink('https://drive.example/files')?.path, '/files');
    });
  });

  group('deciding whether a link is for this server', () {
    test('the same host and port matches however it is written', () {
      expect(
        linkMatchesNode('https://drive.example:443', 'https://drive.example'),
        isTrue,
      );
      expect(
        linkMatchesNode('http://192.168.1.10:80/', 'http://192.168.1.10'),
        isTrue,
      );
    });

    test('a different host does not match', () {
      expect(
        linkMatchesNode('https://other.example', 'https://drive.example'),
        isFalse,
      );
    });

    test('the same host on a different port does not match', () {
      // two servers on one machine is a real self hosted setup, so the port
      // genuinely distinguishes them
      expect(
        linkMatchesNode('https://192.168.1.10:7443', 'https://192.168.1.10:8443'),
        isFalse,
      );
    });

    test('a link that names no server never prompts', () {
      expect(linkMatchesNode('', 'https://drive.example'), isTrue);
    });
  });
}
