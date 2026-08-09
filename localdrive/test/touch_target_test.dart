import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/constants/ld_radii.dart';
import 'package:localdrive/core/widgets/ld_button.dart';
import 'package:localdrive/core/widgets/ld_icons.dart';

/// Both the Material guidelines and Apple's set 48 as the smallest thing a
/// finger should have to hit. The utility button is drawn at 42 because that
/// is what the toolbar wants to look like, so the target has to be grown
/// separately or every icon button in the app is under the minimum.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('a utility button is at least 48 across to hit', (tester) async {
    await tester.pumpWidget(
      wrap(LdUtilityButton(glyph: LdGlyph.search, onPressed: () {})),
    );

    final size = tester.getSize(find.byType(LdUtilityButton));
    expect(
      size.width,
      greaterThanOrEqualTo(LdRadii.minTouchTarget),
      reason: 'the tap target is narrower than a fingertip',
    );
    expect(size.height, greaterThanOrEqualTo(LdRadii.minTouchTarget));
  });

  testWidgets('it still draws at the smaller size', (tester) async {
    await tester.pumpWidget(
      wrap(LdUtilityButton(glyph: LdGlyph.search, onPressed: () {})),
    );

    // the visible circle is the Container inside, not the target around it
    final circle = tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byType(LdUtilityButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(circle, isNotEmpty, reason: 'the drawn circle went missing');

    final drawn = tester.getSize(
      find
          .descendant(
            of: find.byType(LdUtilityButton),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      drawn.width,
      LdRadii.utilityButtonSize,
      reason: 'growing the target must not grow the drawing',
    );
  });

  testWidgets('a tap still reaches the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(LdUtilityButton(glyph: LdGlyph.search, onPressed: () => taps++)),
    );

    await tester.tap(find.byType(LdUtilityButton));
    await tester.pump();
    expect(taps, 1);
  });
}
