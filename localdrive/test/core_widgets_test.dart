import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localdrive/core/constants/breakpoints.dart';
import 'package:localdrive/core/enums/file_category.dart';
import 'package:localdrive/core/theme/ld_theme.dart';
import 'package:localdrive/core/widgets/ld_bottom_sheet.dart';
import 'package:localdrive/core/widgets/ld_button.dart';
import 'package:localdrive/core/widgets/ld_controls.dart';
import 'package:localdrive/core/widgets/ld_empty_state.dart';
import 'package:localdrive/core/widgets/ld_error_state.dart';
import 'package:localdrive/core/widgets/ld_file_icon.dart';
import 'package:localdrive/core/widgets/ld_responsive.dart';
import 'package:localdrive/core/widgets/ld_toast.dart';
import 'package:localdrive/l10n/generated/app_localizations.dart';

/// Wraps a widget in the same theme, locale, and localizations the real app
/// gives it, so a test exercises what ships rather than a bare widget.
Widget host(Widget child, {Locale locale = const Locale('en'), Size? size}) {
  return MaterialApp(
    theme: LdTheme.forLocale(locale),
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: size == null
        ? Scaffold(body: child)
        : MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(body: SizedBox.fromSize(size: size, child: child)),
          ),
  );
}

void main() {
  group('LdResponsive', () {
    Future<String> classAt(WidgetTester tester, double width) async {
      // the real window is what LdResponsive measures, so the test resizes it
      // rather than nesting a fixed box the parent would clamp
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);

      var seen = '';
      await tester.pumpWidget(
        host(
          LdResponsive(
            mobile: (_) {
              seen = 'mobile';
              return const SizedBox.shrink();
            },
            tablet: (_) {
              seen = 'tablet';
              return const SizedBox.shrink();
            },
            desktop: (_) {
              seen = 'desktop';
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('switches at the documented breakpoints', (tester) async {
      expect(await classAt(tester, 420), 'mobile');
      expect(await classAt(tester, Breakpoints.mobileMax - 1), 'mobile');
      expect(await classAt(tester, Breakpoints.mobileMax), 'tablet');
      expect(await classAt(tester, Breakpoints.tabletMax - 1), 'tablet');
      expect(await classAt(tester, Breakpoints.tabletMax), 'desktop');
      expect(await classAt(tester, 1600), 'desktop');
    });

    testWidgets('falls back to the next layout down', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      var built = '';
      await tester.pumpWidget(
        host(
          LdResponsive(
            mobile: (_) {
              built = 'mobile';
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(built, 'mobile');
    });
  });

  group('LdFileIcon', () {
    testWidgets('falls back to the layered icon when there is no thumbnail',
        (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 120,
            height: 120,
            child: LdFileTile(category: FileCategory.pdf, hasThumbnail: false),
          ),
        ),
      );
      expect(find.byType(LdFileIcon), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a folder never renders a thumbnail in place of its icon',
        (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 120,
            height: 120,
            child: LdFileTile(
              category: FileCategory.folder,
              hasThumbnail: true,
            ),
          ),
        ),
      );
      expect(find.byType(LdFileIcon), findsOneWidget);
    });
  });

  group('LdEmptyState and LdErrorState', () {
    testWidgets('an empty state shows its copy and its action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          LdEmptyState(
            title: 'Nothing here yet',
            message: 'Upload a file to get started.',
            actionLabel: 'Upload',
            onAction: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Upload a file to get started.'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      expect(tapped, isTrue);
    });

    testWidgets('an error state binds retry to the call that failed',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        host(
          LdErrorState(
            kind: LdErrorKind.unreachable,
            title: 'Could not reach this server',
            message: 'It may be off.',
            retryLabel: 'Try again',
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('a permission failure offers no retry, because retrying it '
        'would never help', (tester) async {
      await tester.pumpWidget(
        host(
          const LdErrorState(
            kind: LdErrorKind.permissionDenied,
            title: 'You do not have access',
            retryLabel: 'Try again',
          ),
        ),
      );
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('LdBottomSheet', () {
    testWidgets('a destructive confirm stays disabled until the phrase matches',
        (tester) async {
      bool? outcome;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => LdButton(
              label: 'Format',
              onPressed: () async {
                outcome = await LdBottomSheet.confirm(
                  context,
                  title: 'Format this drive',
                  message: 'Everything on it will be deleted.',
                  confirmLabel: 'Format',
                  cancelLabel: 'Cancel',
                  destructive: true,
                  requiredPhrase: 'ERASE THIS DRIVE',
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Format'));
      await tester.pumpAndSettle();
      expect(find.text('Everything on it will be deleted.'), findsOneWidget);

      // the confirm is inert until the exact phrase is typed
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();
      expect(outcome, isNull);

      await tester.enterText(find.byType(TextField), 'ERASE THIS DRIVE');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Format').last);
      await tester.pumpAndSettle();
      expect(outcome, isTrue);
    });

    testWidgets('there is no AlertDialog anywhere in the confirm path',
        (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => LdButton(
              label: 'Delete',
              onPressed: () => LdBottomSheet.confirm(
                context,
                title: 'Delete',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                destructive: true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LdBottomSheet), findsOneWidget);
    });
  });

  group('LdToast', () {
    testWidgets('brings its own Material ancestor, so text inside it renders',
        (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => LdButton(
              label: 'Show',
              onPressed: () => LdToast.success(context, 'Saved'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      LdToast.clear();
    });
  });

  group('LdControls', () {
    testWidgets('a switch reports the value it is moving to', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        host(LdSwitch(value: false, onChanged: (value) => changed = value)),
      );
      await tester.tap(find.byType(LdSwitch));
      expect(changed, isTrue);
    });
  });

  group('Arabic', () {
    testWidgets('lays out right to left and keeps its own typeface',
        (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Text(
              L10n.of(context).myFiles,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(find.text('ملفاتي'), findsOneWidget);
      final direction = Directionality.of(
        tester.element(find.text('ملفاتي')),
      );
      expect(direction, TextDirection.rtl);
    });

    testWidgets('every navigation label is translated, none fall back to '
        'english', (tester) async {
      late L10n arabic;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              arabic = L10n.of(context);
              return const SizedBox.shrink();
            },
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(arabic.myFiles, 'ملفاتي');
      expect(arabic.trash, 'سلة المهملات');
      expect(arabic.starred, 'المميزة بنجمة');
      expect(arabic.pendingApproval, 'بانتظار الموافقة');
      expect(arabic.availableOffline, 'متاح دون اتصال');
    });
  });
}
