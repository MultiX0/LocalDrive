import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/router/routes.dart';
import 'package:localdrive/features/settings/settings_section.dart';

void main() {
  group('builders', () {
    test('every id route is built from its own base path', () {
      expect(Routes.folder('abc'), '${Routes.files}/abc');
      expect(Routes.photo('abc'), '${Routes.gallery}/abc');
      expect(Routes.sharedNode('abc'), '${Routes.shared}/abc');
      expect(Routes.previewOf('abc'), '${Routes.preview}/abc');
      expect(Routes.publicShare('tok'), '${Routes.share}/tok');
      expect(Routes.inviteLink('code'), '${Routes.invite}/code');
    });

    test('a segment that would change the path shape is encoded', () {
      // a node id is opaque, and one containing a slash must not silently
      // become two path segments
      expect(Routes.folder('a/b'), '${Routes.files}/a%2Fb');
      expect(Routes.folder('a b'), '${Routes.files}/a%20b');
    });
  });

  group('idIn', () {
    test('reads the id back out of a location', () {
      expect(Routes.folderIdIn('/files/abc'), 'abc');
      expect(Routes.idIn(Routes.gallery, '/gallery/xyz'), 'xyz');
    });

    test('round trips whatever the builder produced', () {
      for (final id in <String>['abc', 'a/b', 'a b', 'ünïcode']) {
        expect(Routes.folderIdIn(Routes.folder(id)), id);
      }
    });

    test('is null when there is no id', () {
      expect(Routes.folderIdIn(Routes.files), isNull);
      expect(Routes.folderIdIn('/files/'), isNull);
      expect(Routes.folderIdIn('/gallery/abc'), isNull);
      expect(Routes.folderIdIn('/'), isNull);
    });

    test('takes only the first segment', () {
      expect(Routes.folderIdIn('/files/abc/def'), 'abc');
    });

    test('does not match a base that is only a prefix of another', () {
      // /shared must not be read as an id under /share
      expect(Routes.idIn(Routes.share, Routes.shared), isNull);
    });
  });

  group('onboarding routes', () {
    test('the plain onboarding pages are recognised', () {
      expect(isOnboarding(Routes.welcome), isTrue);
      expect(isOnboarding(Routes.connect), isTrue);
      expect(isOnboarding(Routes.signIn), isTrue);
      expect(isOnboarding(Routes.createAccount), isTrue);
    });

    test('an invite link carrying a code is still onboarding', () {
      // this returned false, so the router sent the person to sign in and the
      // invite code went with the redirect. It broke every invite ever sent.
      expect(isOnboarding(Routes.child(Routes.createAccount, 'ALD6-YJ2V')),
          isTrue);
      expect(isOnboarding('/create-account/abc'), isTrue);
    });

    test('a signed in destination is not onboarding', () {
      expect(isOnboarding(Routes.files), isFalse);
      expect(isOnboarding(Routes.settings), isFalse);
      expect(isOnboarding(Routes.folder('abc')), isFalse);
      // a lookalike prefix must not slip through
      expect(isOnboarding('/create-accounts-report'), isFalse);
    });
  });

  group('SettingsSection', () {
    test('ids are unique', () {
      final ids = SettingsSection.values.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every id resolves back to its own section', () {
      for (final section in SettingsSection.values) {
        expect(SettingsSection.fromId(section.id), section);
      }
    });

    test('an unknown or absent id is null rather than a wrong section', () {
      expect(SettingsSection.fromId('nope'), isNull);
      expect(SettingsSection.fromId(null), isNull);
      expect(SettingsSection.fromId(''), isNull);
    });

    test('routes live under settings and match the shared constants', () {
      expect(SettingsSection.about.route, Routes.settingsAbout);
      expect(SettingsSection.devices.route, Routes.settingsDevices);
      expect(SettingsSection.users.route, Routes.settingsUsers);
      expect(SettingsSection.server.route, Routes.settingsServer);
      expect(SettingsSection.language.route, Routes.settingsLanguage);
      expect(SettingsSection.downloads.route, Routes.settingsDownloads);
      expect(SettingsSection.account.route, Routes.settingsAccount);
    });

    test('admin only sections are hidden from an ordinary account', () {
      final ordinary = SettingsSection.visibleTo(isAdmin: false);
      expect(ordinary, isNot(contains(SettingsSection.users)));
      expect(ordinary, isNot(contains(SettingsSection.server)));
      expect(ordinary, contains(SettingsSection.devices));

      final admin = SettingsSection.visibleTo(isAdmin: true);
      expect(admin, contains(SettingsSection.users));
      expect(admin, contains(SettingsSection.server));
    });
  });
}

/// The router treats these as onboarding, which is what decides whether a
/// redirect sends someone to sign in or lets the page through.
///
/// An invite link is /create-account/<code>. Matching that set exactly, as the
/// router first did, misses it: every invite link was bounced to sign in and
/// the code was lost on the way.
bool isOnboarding(String location) {
  const routes = <String>{
    Routes.welcome,
    Routes.connect,
    Routes.language,
    Routes.setup,
    Routes.signIn,
    Routes.createAccount,
  };
  return routes.contains(location) ||
      location.startsWith('${Routes.createAccount}/');
}
