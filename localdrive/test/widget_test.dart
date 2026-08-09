import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/constants/ld_colors.dart';
import 'package:localdrive/core/theme/ld_theme.dart';
import 'package:localdrive/core/widgets/ld_button.dart';

void main() {
  testWidgets('a primary button renders its label and fires once', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: LdTheme.forLocale(const Locale('en')),
        home: Scaffold(
          body: LdButton(label: 'Continue', onPressed: () => taps++),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });

  testWidgets('a disabled button does not fire', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LdTheme.forLocale(const Locale('en')),
        home: const Scaffold(body: LdButton(label: 'Save')),
      ),
    );

    await tester.tap(find.text('Save'));
    expect(tester.takeException(), isNull);
  });

  test('the palette keeps its two brand accents', () {
    expect(LdColors.accentPrimary.toARGB32(), 0xFF4C8DFF);
    expect(LdColors.accentWarning.toARGB32(), 0xFFEE7759);
    expect(LdColors.backgroundPrimary.toARGB32(), 0xFF141414);
  });
}
