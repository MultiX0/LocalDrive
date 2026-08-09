import 'package:flutter/widgets.dart';

/// Corner radii, sized once so nothing invents its own.
abstract final class LdRadii {
  static const double card = 16;

  /// half of the 48dp button height, which makes a stadium
  static const double pill = 24;
  static const double sheet = 16;
  static const double field = 12;
  static const double chip = 10;
  static const double tile = 14;

  /// the circular utility button from the reference screens
  static const double utilityButtonSize = 42;

  /// The smallest a tap target may be, from both the Material and Apple
  /// guidelines. A control may look smaller than this; it may not be smaller
  /// than this to hit.
  static const double minTouchTarget = 48;
  static const double buttonHeight = 48;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius fieldRadius =
      BorderRadius.all(Radius.circular(field));
  static const BorderRadius tileRadius = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}
