import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ld_empty_state.dart';
import 'ld_error_state.dart';
import 'ld_icons.dart';
import 'ld_spinner.dart';

/// Renders an AsyncValue exhaustively, every time.
///
/// The error branch is always LdErrorState with a real retry, and an empty
/// data branch is always LdEmptyState. This widget exists so no screen can
/// quietly skip either one.
class LdAsync<T> extends StatelessWidget {
  const LdAsync({
    super.key,
    required this.value,
    required this.data,
    required this.errorCopy,
    required this.onRetry,
    this.loading,
    this.isEmpty,
    this.empty,
    this.compact = false,
    this.skipLoadingOnRefresh = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// localized copy, handed in so this widget holds no English
  final LdErrorCopy errorCopy;
  final VoidCallback onRetry;
  final Widget? loading;

  /// what counts as nothing to show for this particular T
  final bool Function(T data)? isEmpty;
  final Widget Function()? empty;
  final bool compact;
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnRefresh,
      loading: () => loading ?? const Center(child: LdSpinner()),
      error: (error, _) => LdErrorState.from(
        error,
        copy: errorCopy,
        onRetry: onRetry,
        compact: compact,
      ),
      data: (result) {
        if (isEmpty != null && isEmpty!(result)) {
          return empty?.call() ??
              LdEmptyState(
                title: errorCopy.title(LdErrorKind.notFound),
                glyph: LdGlyph.folder,
                compact: compact,
              );
        }
        return data(result);
      },
    );
  }
}

/// A slim variant for something inline, such as a count in a header, where a
/// full error state would be out of scale.
class LdAsyncInline<T> extends StatelessWidget {
  const LdAsyncInline({
    super.key,
    required this.value,
    required this.data,
    this.fallback = const SizedBox.shrink(),
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => value.maybeWhen(
        data: data,
        orElse: () => fallback,
      );
}
