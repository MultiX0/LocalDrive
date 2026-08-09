import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/pages/about_page.dart';
import '../../features/settings/settings_section.dart';
import '../../features/activity/pages/activity_page.dart';
import '../../features/auth/controller/session_controller.dart';
import '../../features/auth/controller/session_state.dart';
import '../../features/auth/pages/change_password_page.dart';
import '../../features/auth/pages/pending_approval_page.dart';
import '../../features/auth/pages/sign_in_page.dart';
import '../../features/auth/pages/two_factor_setup_page.dart';
import '../../features/files/pages/files_page.dart';
import '../../features/onboarding/pages/connect_page.dart';
import '../../features/onboarding/pages/language_page.dart';
import '../../features/onboarding/pages/setup_page.dart';
import '../../features/onboarding/pages/welcome_page.dart';
import '../../features/preview/pages/preview_page.dart';
import '../../features/search/pages/search_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/shared/pages/shared_page.dart';
import '../../features/gallery/pages/gallery_page.dart';
import '../../features/gallery/pages/photo_viewer_page.dart';
import '../../features/shell/pages/app_shell.dart';
import '../../features/storage/pages/storage_page.dart';
import '../../features/trash/pages/trash_page.dart';
import '../../features/upload/pages/transfers_page.dart';
import '../constants/ld_motion.dart';
import 'routes.dart';

/// The one router. Its redirect is driven entirely by SessionStage, so there
/// is a single source of truth for which screen a person should see.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.files,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, routerState) {
      final session = ref.read(sessionProvider);
      final location = routerState.matchedLocation;

      // a public share link is readable with no session at all
      if (location.startsWith('${Routes.share}/')) return null;

      const onboardingRoutes = <String>{
        Routes.welcome,
        Routes.connect,
        Routes.language,
        Routes.setup,
        Routes.signIn,
        Routes.createAccount,
      };
      // the create account route carries an invite code as a path segment, so
      // an exact match misses /create-account/ABCD-1234 and bounces it to sign
      // in, taking the code with it. That is every invite link ever sent.
      final onboarding = onboardingRoutes.contains(location) ||
          location.startsWith('${Routes.createAccount}/');

      return switch (session.stage) {
        SessionStage.restoring => null,
        SessionStage.noNode =>
          location == Routes.welcome || location == Routes.connect
              ? null
              : Routes.welcome,
        SessionStage.signedOut => onboarding ? null : Routes.signIn,
        SessionStage.pendingApproval =>
          location == Routes.pendingApproval ? null : Routes.pendingApproval,
        SessionStage.mustEnableTotp =>
          location == Routes.twoFactorSetup ? null : Routes.twoFactorSetup,
        SessionStage.mustChangePassword =>
          location == Routes.changePassword ? null : Routes.changePassword,
        // The screens that hold you until you pass them. Once the stage moves
        // on, the screen's job is done and standing on it is being stuck: the
        // two factor page used to say "two-factor is on" and then leave you
        // looking at the same form, because only pendingApproval was listed
        // here and passing any other gate redirected nowhere.
        SessionStage.ready => onboarding ||
                location == Routes.pendingApproval ||
                location == Routes.twoFactorSetup ||
                location == Routes.changePassword
            ? Routes.files
            : null,
      };
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.welcome,
        pageBuilder: _page(const WelcomePage()),
      ),
      GoRoute(
        path: Routes.connect,
        pageBuilder: _page(const ConnectPage()),
      ),
      GoRoute(
        path: Routes.language,
        pageBuilder: _page(const LanguagePage()),
      ),
      GoRoute(
        path: Routes.setup,
        pageBuilder: _page(const SetupPage()),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: _page(const SignInPage()),
      ),
      GoRoute(
        path: Routes.createAccount,
        pageBuilder: _page(const SignInPage(createMode: true)),
      ),
      GoRoute(
        path: '${Routes.createAccount}/${Routes.pattern('code')}',
        pageBuilder: (context, state) => _fade(
          state,
          SignInPage(
            createMode: true,
            inviteCode: state.pathParameters['code'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: Routes.pendingApproval,
        pageBuilder: _page(const PendingApprovalPage()),
      ),
      GoRoute(
        path: Routes.changePassword,
        pageBuilder: _page(const ChangePasswordPage()),
      ),
      GoRoute(
        path: Routes.twoFactorSetup,
        pageBuilder: _page(const TwoFactorSetupPage(required: true)),
      ),

      // an invite link opens straight into create account with the code
      // already filled in, so nobody retypes it
      GoRoute(
        path: '${Routes.invite}/${Routes.pattern('code')}',
        redirect: (context, state) => Routes.child(
          Routes.createAccount,
          state.pathParameters['code'] ?? '',
        ),
      ),

      GoRoute(
        path: '${Routes.share}/${Routes.pattern('token')}',
        pageBuilder: (context, state) => _fade(
          state,
          PreviewPage.publicShare(token: state.pathParameters['token'] ?? ''),
        ),
      ),

      GoRoute(
        path: '${Routes.preview}/${Routes.pattern('id')}',
        pageBuilder: (context, state) => _fade(
          state,
          PreviewPage(nodeId: state.pathParameters['id'] ?? ''),
        ),
      ),

      // full screen, outside the shell, because a photo being looked at wants
      // the whole screen and none of the app's navigation over it
      GoRoute(
        path: '${Routes.gallery}/${Routes.pattern('id')}',
        pageBuilder: (context, state) => _fade(
          state,
          PhotoViewerPage(nodeId: state.pathParameters['id'] ?? ''),
        ),
      ),

      // the main app, which keeps its navigation chrome across every tab
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.files,
            pageBuilder: _page(const FilesPage()),
            routes: <RouteBase>[
              GoRoute(
                path: Routes.pattern('id'),
                pageBuilder: (context, state) => _fade(
                  state,
                  FilesPage(folderId: state.pathParameters['id']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.gallery,
            pageBuilder: _page(const GalleryPage()),
          ),
          GoRoute(
            path: Routes.shared,
            pageBuilder: _page(const SharedPage()),
          ),
          GoRoute(
            path: Routes.starred,
            pageBuilder: _page(const FilesPage(filter: FilesFilter.starred)),
          ),
          GoRoute(
            path: Routes.recent,
            pageBuilder: _page(const FilesPage(filter: FilesFilter.recent)),
          ),
          GoRoute(
            path: Routes.trash,
            pageBuilder: _page(const TrashPage()),
          ),
          GoRoute(
            path: Routes.search,
            pageBuilder: _page(const SearchPage()),
          ),
          GoRoute(
            path: Routes.activity,
            pageBuilder: _page(const ActivityPage()),
          ),
          GoRoute(
            path: Routes.storage,
            pageBuilder: _page(const StoragePage()),
          ),
          GoRoute(
            path: Routes.transfers,
            pageBuilder: _page(const TransfersPage()),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: _page(const SettingsPage()),
            // generated from the enum, so a new section is reachable the
            // moment it is declared and cannot be registered twice or left out
            routes: <RouteBase>[
              GoRoute(
                path: SettingsSection.about.id,
                pageBuilder: _page(const AboutPage()),
              ),
              for (final section in SettingsSection.values)
                if (section != SettingsSection.about)
                  GoRoute(
                    path: section.id,
                    pageBuilder: _page(SettingsPage(section: section.id)),
                  ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Every route uses the app's one transition rather than a platform default.
Page<void> Function(BuildContext, GoRouterState) _page(Widget child) =>
    (context, state) => _fade(state, child);

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: LdMotion.standard,
      reverseTransitionDuration: LdMotion.standard,
      child: child,
      transitionsBuilder: (context, animation, secondary, child) =>
          LdMotion.fadeSlide(animation, child),
    );

/// Bridges the session provider to go_router, which wants a Listenable.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(this._ref) {
    _subscription = _ref.listen<SessionState>(
      sessionProvider,
      (previous, next) {
        if (previous?.stage != next.stage) notifyListeners();
      },
    );
  }

  final Ref _ref;
  late final ProviderSubscription<SessionState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
