import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/theme/ld_theme.dart';
import 'package:localdrive/features/auth/controller/session_controller.dart';
import 'package:localdrive/features/auth/models/user_model.dart';
import 'package:localdrive/features/storage/models/library_model.dart';
import 'package:localdrive/features/storage/widgets/storage_total_card.dart';
import 'package:localdrive/l10n/generated/app_localizations.dart';

/// Whose number is on the storage screen.
///
/// A member must never be shown the server total: on a family server that is
/// reading how much everyone else keeps. An admin runs the box and does need
/// it. The two cases share one widget, so they are worth pinning down.
void main() {
  // 2.2 MB across the whole server, of which this account owns 49 KB
  const summary = LibrarySummary(
    libraries: <LibraryModel>[],
    totalUsed: 2200000,
    totalFree: 20100000000,
    totalBytes: 474200000000,
  );

  UserModel user({required String role}) => UserModel(
        id: 'u1',
        username: 'sara',
        displayName: 'sara',
        role: role,
        avatarSeed: 'seed',
        quotaBytesUsed: 49000,
      );

  Future<void> pump(WidgetTester tester, {required String role}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          isAdminProvider.overrideWithValue(role == 'admin'),
          currentUserProvider.overrideWithValue(user(role: role)),
        ],
        child: MaterialApp(
          theme: LdTheme.forLocale(const Locale('en')),
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(
            body: StorageTotalCard(summary: summary),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // everything the card actually renders, so the assertions do not depend on
  // guessing how bytes are formatted
  String rendered(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .join(' | ');

  testWidgets('a member sees their own files, never the server total',
      (tester) async {
    await pump(tester, role: 'member');
    final text = rendered(tester);

    expect(text, contains('Your files'));
    expect(text, isNot(contains('Across every drive')));

    // 48 KB is this account. 2.1 MB is everyone's files added up, and is the
    // number that must not be here whatever unit it lands in
    expect(text, contains('48 KB'));
    expect(text, isNot(contains('2.1 MB')));
  });

  testWidgets('an admin sees the server total, because running it is the job',
      (tester) async {
    await pump(tester, role: 'admin');
    final text = rendered(tester);

    expect(text, contains('Across every drive'));
    expect(text, isNot(contains('Your files')));
    expect(text, contains('2.1 MB'));
  });

  testWidgets('free space stays device wide for both, because the disk is shared',
      (tester) async {
    for (final role in <String>['member', 'admin']) {
      await pump(tester, role: role);
      expect(
        rendered(tester),
        contains('18.7 GB'),
        reason: '$role should still see how much room is left on the drive',
      );
    }
  });
}
