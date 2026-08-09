/// The one place breakpoints are defined. `LdResponsive` is the only widget
/// that reads them, so nothing hardcodes a width per feature.
abstract final class Breakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  /// grid columns per device class, used by the files browser
  static const int gridColumnsMobile = 2;
  static const int gridColumnsTablet = 4;
  static const int gridColumnsDesktop = 6;

  /// the tablet two pane split
  static const double detailPaneWidth = 380;

  /// the widest a form or a reading column ever gets
  static const double contentMaxWidth = 640;
}

/// The three device classes the presentation layer forks on.
enum DeviceClass {
  mobile,
  tablet,
  desktop;

  bool get isMobile => this == DeviceClass.mobile;
  bool get isTablet => this == DeviceClass.tablet;
  bool get isDesktop => this == DeviceClass.desktop;

  /// hover only exists where there is a pointer, which is what decides
  /// whether the folder content peek animates or just sits open
  bool get hasHover => this == DeviceClass.desktop;

  static DeviceClass fromWidth(double width) {
    if (width < Breakpoints.mobileMax) return DeviceClass.mobile;
    if (width < Breakpoints.tabletMax) return DeviceClass.tablet;
    return DeviceClass.desktop;
  }
}
