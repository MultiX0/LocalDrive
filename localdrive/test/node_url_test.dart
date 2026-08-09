import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/services/api_client.dart';

/// Self hosted means an address on a network far more often than a domain, so
/// the address field has to accept whatever someone actually types.
void main() {
  String normalize(String raw) => ApiClient.normalizeNodeUrl(raw);

  test('a bare address gets the port Local Drive serves on', () {
    expect(normalize('192.168.1.10'), 'http://192.168.1.10:7443');
    expect(normalize('10.0.0.4'), 'http://10.0.0.4:7443');
    expect(normalize('  192.168.1.10  '), 'http://192.168.1.10:7443');
  });

  test('an explicit port is left exactly as typed', () {
    expect(normalize('192.168.1.10:9000'), 'http://192.168.1.10:9000');
    expect(normalize('http://192.168.1.10:8080'), 'http://192.168.1.10:8080');
  });

  test('a full url means exactly that url, port and all', () {
    // typing the scheme is a statement about the address; only a bare address
    // is a statement about wanting Local Drive
    expect(normalize('http://192.168.1.10'), 'http://192.168.1.10');
    expect(normalize('https://192.168.1.10'), 'https://192.168.1.10');
  });

  test('a hostname works the same way as an address', () {
    expect(normalize('nas.local'), 'http://nas.local:7443');
    expect(normalize('nas.local:7443'), 'http://nas.local:7443');
  });

  test('the scheme is guessed from what the address can have a cert for', () {
    // nothing issues a certificate for an ip or a name that only resolves on
    // this network, so those get http
    expect(normalize('192.168.1.10'), startsWith('http://'));
    expect(normalize('nas'), startsWith('http://'));
    expect(normalize('nas.local'), startsWith('http://'));
    expect(normalize('nas.lan'), startsWith('http://'));
    expect(normalize('nas.home'), startsWith('http://'));
    expect(normalize('nas.internal'), startsWith('http://'));

    // a public domain can have one, so it gets https
    expect(normalize('drive.mysite.tld'), startsWith('https://'));

    // and typing a scheme always wins over the guess
    expect(normalize('https://192.168.1.10'), startsWith('https://'));
    expect(normalize('http://drive.mysite.tld'), startsWith('http://'));
  });

  test('a domain someone actually owns keeps its own port', () {
    expect(normalize('https://drive.mysite.tld'), 'https://drive.mysite.tld');
    // a port that is already the scheme's default drops out, which is the
    // same address either way
    expect(normalize('https://drive.mysite.tld:443'), 'https://drive.mysite.tld');
    expect(normalize('https://drive.mysite.tld:8443'), 'https://drive.mysite.tld:8443');
    // but a bare domain still means "my server", so it gets our port
    expect(normalize('drive.mysite.tld'), 'https://drive.mysite.tld:7443');
  });

  test('a trailing slash never doubles up in a built path', () {
    expect(normalize('192.168.1.10/'), 'http://192.168.1.10:7443');
    expect(normalize('https://192.168.1.10:7443///'), 'https://192.168.1.10:7443');
    expect(normalize('nas.local/'), 'http://nas.local:7443');
  });

  test('an empty field stays empty rather than becoming a bad url', () {
    expect(normalize(''), '');
    expect(normalize('   '), '');
  });
}
