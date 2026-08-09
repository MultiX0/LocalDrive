import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../constants/breakpoints.dart';

/// The single breakpoint decision point for the whole app. Nothing else reads
/// a width to pick a layout.
class LdResponsive extends StatelessWidget {
  const LdResponsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;

  /// falls back to mobile with wider columns when absent
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceClass = DeviceClass.fromWidth(constraints.maxWidth);
        return LdDeviceScope(
          deviceClass: deviceClass,
          child: Builder(
            builder: (context) => switch (deviceClass) {
              DeviceClass.desktop => (desktop ?? tablet ?? mobile)(context),
              DeviceClass.tablet => (tablet ?? mobile)(context),
              DeviceClass.mobile => mobile(context),
            },
          ),
        );
      },
    );
  }
}

/// Carries the resolved device class down the tree so a leaf widget can adapt
/// without measuring again.
class LdDeviceScope extends InheritedWidget {
  const LdDeviceScope({
    super.key,
    required this.deviceClass,
    required super.child,
  });

  final DeviceClass deviceClass;

  static DeviceClass of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LdDeviceScope>();
    if (scope != null) return scope.deviceClass;
    return DeviceClass.fromWidth(MediaQuery.sizeOf(context).width);
  }

  @override
  bool updateShouldNotify(LdDeviceScope oldWidget) =>
      oldWidget.deviceClass != deviceClass;
}

/// Shorthands used all over the presentation layer.
extension LdResponsiveContext on BuildContext {
  DeviceClass get deviceClass => LdDeviceScope.of(this);
  bool get isDesktop => deviceClass.isDesktop;

  double get pagePadding => switch (deviceClass) {
        DeviceClass.mobile => 20,
        DeviceClass.tablet => 28,
        DeviceClass.desktop => 32,
      };

  int get gridColumns => switch (deviceClass) {
        DeviceClass.mobile => Breakpoints.gridColumnsMobile,
        DeviceClass.tablet => Breakpoints.gridColumnsTablet,
        DeviceClass.desktop => Breakpoints.gridColumnsDesktop,
      };
}


/// Whether this build is driven by a pointer rather than a thumb.
///
/// Width alone cannot answer this. A Local Drive window dragged narrow on
/// Windows is still Windows: it has a mouse, a right button and a keyboard,
/// and a sheet sliding up from the bottom of it is a phone gesture wearing a
/// desktop's clothes. Layout still follows width; what a menu or a modal
/// should *be* follows the machine.
bool get isPointerPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);


/// Whether this screen should behave like a desktop, as opposed to look like
/// one.
///
/// Layout follows the width it was given. Behaviour must not, and this is where
/// that went wrong: the file grid measures the space left after the sidebar, so
/// a 1180 pixel window leaves about 930 for content, which lands under the
/// desktop breakpoint. Drag, marquee, ctrl click and double click to open all
/// switched themselves off, and the same window maximised turned them back on.
/// Nothing about the machine changed in between. A mouse is a mouse at any
/// window size.
bool desktopBehaviour(BuildContext context) =>
    isPointerPlatform || context.deviceClass.isDesktop;
