import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/constants/breakpoints.dart';
import 'package:localdrive/core/widgets/ld_content_pane.dart';
import 'package:localdrive/core/widgets/ld_responsive.dart';

/// The measure that stops a phone layout being stretched across a desktop.
void main() {
  behaviourTests();
  const marker = Key('content');

  Future<double> widthAt(WidgetTester tester, double window) async {
    tester.view.physicalSize = Size(window, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // LdResponsive is the only thing that resolves a device class, so
          // the pane has to sit under one exactly as it does in the app
          body: LdResponsive(
            mobile: (context) => const LdContentPane(
              child: SizedBox.expand(key: marker),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(marker)).width;
  }

  testWidgets('a phone window is already the measure, so nothing is imposed',
      (tester) async {
    expect(await widthAt(tester, 375), 375);
  });

  testWidgets('a desktop window holds content to a readable width',
      (tester) async {
    expect(await widthAt(tester, 1440), Breakpoints.contentMaxWidth);
  });

  testWidgets('a tablet window is held too, not left to stretch',
      (tester) async {
    expect(await widthAt(tester, 900), Breakpoints.contentMaxWidth);
  });

  testWidgets('a window narrower than the cap keeps every pixel it has',
      (tester) async {
    // 620 is a tablet by breakpoint but narrower than the 640 cap, so the cap
    // must not widen it back out
    expect(await widthAt(tester, 620), 620);
  });
}

/// Desktop behaviour must not switch itself off when the window narrows.
///
/// The file grid measures the space left after the sidebar, so a 1180 pixel
/// window leaves roughly 930 for content and lands under the desktop
/// breakpoint. Drag, marquee and ctrl click used to vanish there and come back
/// when the same window was maximised.
void behaviourTests() {
  testWidgets('a narrow content area still behaves like a desktop', (tester) async {
    late bool behaves;
    tester.view.physicalSize = const Size(930, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LdResponsive(
          mobile: (context) => Builder(
            builder: (context) {
              behaves = desktopBehaviour(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // on a pointer platform this is true whatever the width; in the test VM
    // isPointerPlatform is false, so this pins the width half of the rule
    expect(behaves, LdDeviceScope.of(tester.element(find.byType(SizedBox))).isDesktop);
  });
}
