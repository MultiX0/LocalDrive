import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../services/api_exception.dart';
import 'ld_button.dart';
import 'ld_empty_state.dart';
import 'ld_icons.dart';

/// The kinds of failure the app distinguishes, each with its own short copy
/// and icon. A generic "something went wrong" is the last resort, not the
/// default.
enum LdErrorKind {
  offline,
  unreachable,
  permissionDenied,
  notFound,
  quota,
  sessionExpired,
  unexpected,
}

/// Every async failure renders this, with a Retry bound to the specific call
/// that failed. There is no `Text('Error: $e')` anywhere, and this is also the
/// target of the global ErrorWidget.builder override.
class LdErrorState extends StatelessWidget {
  const LdErrorState({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.compact = false,
  });

  /// Builds the right state from whatever the data layer threw, so a caller
  /// never has to classify an error itself.
  factory LdErrorState.from(
    Object error, {
    required LdErrorCopy copy,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    final kind = _classify(error);
    return LdErrorState(
      kind: kind,
      title: copy.title(kind),
      message: copy.message(kind),
      retryLabel: copy.retryLabel,
      onRetry: kind == LdErrorKind.permissionDenied ? null : onRetry,
      compact: compact,
    );
  }

  final LdErrorKind kind;
  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  static LdErrorKind _classify(Object error) {
    if (error is ApiException) {
      return switch (error.kind) {
        ApiErrorKind.offline => LdErrorKind.offline,
        ApiErrorKind.unreachable => LdErrorKind.unreachable,
        ApiErrorKind.unauthorized => LdErrorKind.sessionExpired,
        ApiErrorKind.forbidden => LdErrorKind.permissionDenied,
        ApiErrorKind.notFound => LdErrorKind.notFound,
        ApiErrorKind.quota => LdErrorKind.quota,
        _ => LdErrorKind.unexpected,
      };
    }
    return LdErrorKind.unexpected;
  }

  LdGlyph get _glyph => switch (kind) {
        LdErrorKind.offline => LdGlyph.offline,
        LdErrorKind.unreachable => LdGlyph.server,
        LdErrorKind.permissionDenied => LdGlyph.lock,
        LdErrorKind.notFound => LdGlyph.search,
        LdErrorKind.quota => LdGlyph.drive,
        LdErrorKind.sessionExpired => LdGlyph.person,
        LdErrorKind.unexpected => LdGlyph.warning,
      };

  Color get _tint => switch (kind) {
        LdErrorKind.offline || LdErrorKind.unreachable =>
          LdColors.foregroundSecondary,
        _ => LdColors.accentWarning,
      };

  @override
  Widget build(BuildContext context) {
    return LdEmptyState(
      title: title,
      message: message,
      glyph: _glyph,
      tint: _tint,
      compact: compact,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}

/// The localized copy for every error kind, handed in so this widget stays
/// free of hardcoded English.
class LdErrorCopy {
  const LdErrorCopy({
    required this.titles,
    required this.messages,
    required this.retryLabel,
  });

  final Map<LdErrorKind, String> titles;
  final Map<LdErrorKind, String> messages;
  final String retryLabel;

  String title(LdErrorKind kind) =>
      titles[kind] ?? titles[LdErrorKind.unexpected] ?? '';

  String? message(LdErrorKind kind) => messages[kind];
}

/// A compact inline banner, for a failure that should not take over a screen.
class LdErrorBanner extends StatelessWidget {
  const LdErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.tint,
    this.glyph = LdGlyph.warning,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final Color? tint;
  final LdGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? LdColors.accentWarning;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LdColors.wash(accent, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LdColors.wash(accent, 0.35)),
      ),
      child: Row(
        children: <Widget>[
          LdIcon(glyph, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: LdColors.foregroundPrimary,
                  ),
            ),
          ),
          if (onRetry != null && retryLabel != null) ...<Widget>[
            const SizedBox(width: 8),
            LdButton.text(label: retryLabel!, onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
