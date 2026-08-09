import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/services/api_client.dart';
import 'package:localdrive/core/services/secure_store_service.dart';
import 'package:localdrive/features/share/models/share_model.dart';

/// The ordinary self-hosted server has no domain, so it cannot know its own
/// address and sends a bare path for a share or invite link. Copying that
/// straight to the clipboard hands someone a link with nothing to open, so
/// the client has to fill in whatever address it is actually connected to.
void main() {
  ApiClient clientOn(String node) =>
      ApiClient(store: SecureStoreService())..useNode(node);

  group('ApiClient.publicLink', () {
    test('a bare path gets the connected server prepended', () {
      final api = clientOn('192.168.1.10');
      expect(
        api.publicLink('/s/abc123'),
        'http://192.168.1.10:7443/s/abc123',
      );
    });

    test('a link that already has a scheme is left exactly alone', () {
      final api = clientOn('192.168.1.10');
      // the server only sends this when an admin configured a domain, and
      // that address is correct regardless of which node answered
      expect(
        api.publicLink('https://drive.mysite.tld/s/abc123'),
        'https://drive.mysite.tld/s/abc123',
      );
    });

    test('an empty link stays empty rather than becoming just the node', () {
      final api = clientOn('192.168.1.10');
      expect(api.publicLink(''), '');
    });
  });

  group('ShareModel.fromJson', () {
    test('resolves a bare url through the given resolver', () {
      final model = ShareModel.fromJson(
        <String, dynamic>{
          'id': 'share1',
          'node_id': 'node1',
          'token': 'abc123',
          'url': '/s/abc123',
          'allow_download': true,
          'password_protected': false,
          'active': true,
        },
        resolveUrl: (raw) => 'http://192.168.1.10:7443$raw',
      );

      expect(model.url, 'http://192.168.1.10:7443/s/abc123');
    });
  });
}
