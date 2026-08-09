import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/router/routes.dart';
import 'package:localdrive/features/shell/pages/app_shell.dart';

/// Where the phone tab bar belongs.
///
/// It kept appearing on screens opened from inside Settings, lighting up Home
/// while you stood on Storage. The rule is now stated as what the tabs are, so
/// a new screen is hidden by default rather than silently inheriting a bar it
/// has no place in.
void main() {
  test('the tab bar shows on the four destinations and inside folders', () {
    for (final location in <String>[
      Routes.files,
      '${Routes.files}/some-folder-id',
      Routes.gallery,
      Routes.shared,
      Routes.settings,
      '${Routes.settings}/language',
    ]) {
      expect(
        isTabDestination(location),
        isTrue,
        reason: '$location is a tab destination and should keep the bar',
      );
    }
  });

  test('every screen opened from inside another one hides it', () {
    for (final location in <String>[
      Routes.storage,
      Routes.trash,
      Routes.activity,
      Routes.starred,
      Routes.recent,
      Routes.search,
      Routes.transfers,
    ]) {
      expect(
        isTabDestination(location),
        isFalse,
        reason: '$location is not a tab, so the bar would be pointing at '
            'somewhere you are not',
      );
    }
  });
}
