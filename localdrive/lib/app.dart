import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/core_providers.dart';
import 'features/shell/widgets/deep_link_listener.dart';
import 'features/shell/widgets/live_event_listener.dart';
import 'features/shell/widgets/platform_bootstrap.dart';
import 'l10n/generated/app_localizations.dart';

/// The app root. Theme and locale are composed once here, so the Latin and
/// Arabic typefaces swap at the ThemeData level and reach every piece of text.
class LocalDriveApp extends ConsumerWidget {
  const LocalDriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final theme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Local Drive',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // one listener for the whole app turns live events into cache
        // invalidations and toasts, so no page has to subscribe itself
        return PlatformBootstrap(
          child: LiveEventListener(
            child: DeepLinkListener(
              child: MediaQuery.withNoTextScaling(
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
    );
  }
}
