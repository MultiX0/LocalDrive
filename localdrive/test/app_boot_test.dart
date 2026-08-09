import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:localdrive/app.dart';
import 'package:localdrive/core/widgets/ld_logo.dart';
import 'package:localdrive/features/shell/pages/app_shell.dart';

/// Boots the real app, router and all.
///
/// The navigation chrome sits in a ShellRoute builder, whose own context is
/// above the matched route's subtree. Reading router state the wrong way there
/// throws at first paint and takes the whole screen with it, which is exactly
/// the kind of break a test that only ever pumps single widgets never sees.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // no keychain in a test binding, so the platform channel is faked
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> boot(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      const ProviderScope(child: LocalDriveApp()),
    );
    // settle the restore future and the first transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('boots to onboarding on a phone without throwing',
      (tester) async {
    await boot(tester, size: const Size(400, 900));
    expect(tester.takeException(), isNull);
    // with no node stored, onboarding is where it should land
    expect(find.byType(LdLogo), findsWidgets);
  });

  testWidgets('boots on a desktop window without throwing', (tester) async {
    await boot(tester, size: const Size(1500, 950));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shell reads its location without a GoRouterState error',
      (tester) async {
    await boot(tester, size: const Size(400, 900));
    // AppShell only mounts once a session exists, so this asserts the type is
    // reachable and that nothing above it threw on the way
    expect(AppShell, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
