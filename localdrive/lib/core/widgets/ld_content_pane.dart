import 'package:flutter/widgets.dart';

import '../constants/breakpoints.dart';
import 'ld_responsive.dart';

/// Holds content to a readable width and centres it on a wide window,
/// instead of stretching a phone layout across a 1440 pixel one. Every
/// settings, reading and single task screen goes through here.
///
/// This is a measure, not a layout: a screen that genuinely wants a different
/// shape on a desktop, such as a list beside a detail pane, still builds one
/// with [LdResponsive]. Nothing changes on a phone, where the window already is
/// the measure.
class LdContentPane extends StatelessWidget {
  const LdContentPane({
    super.key,
    required this.child,
    this.maxWidth = _form,
  });

  /// A single task: sign in, confirm a code, change a password.
  ///
  /// The same measure the change password and pending approval screens already
  /// used, so every focused screen lines up rather than each picking a number.
  static const double _form = Breakpoints.contentMaxWidth;

  /// A list that is mostly one column of items but reads better with a little
  /// more room, such as transfers or activity.
  static const double list = 860;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (context.deviceClass == DeviceClass.mobile) return child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
