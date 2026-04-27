import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/about/about_screen.dart';
import '../../features/auth/auth_session.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/medications/add_medication_screen.dart';
import '../../features/caregiver/caregiver_alerts_screen.dart';
import '../../features/history/intake_history_screen.dart';
import '../../features/medications/medications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/timer/timer_screen.dart';

String _shellHomeForRole(String? role) {
  if (role == 'caregiver') {
    return '/medications';
  }
  return '/timer';
}

GoRouter createAppRouter(AuthSession auth) {
  return GoRouter(
    initialLocation: auth.isAuthenticated ? _shellHomeForRole(auth.role) : '/login',
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) {
      final loc = state.matchedLocation;
      final public = loc == '/login' || loc == '/register';
      final session = Provider.of<AuthSession>(context, listen: false);
      final authed = session.isAuthenticated;
      final role = session.role;
      if (!authed && !public) {
        return '/login';
      }
      if (authed && public) {
        return _shellHomeForRole(role);
      }
      if (authed && role == 'caregiver' && loc == '/timer') {
        return '/medications';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timer',
                name: 'timer',
                pageBuilder: (context, state) => const NoTransitionPage<void>(child: TimerScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/medications',
                name: 'medications',
                pageBuilder: (context, state) => const NoTransitionPage<void>(child: MedicationsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: 'history_tab',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: IntakeHistoryScreen(embeddedInShell: true)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage<void>(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/intake-history',
        name: 'intake_history',
        builder: (context, state) => const IntakeHistoryScreen(),
      ),
      GoRoute(
        path: '/caregiver-alerts',
        name: 'caregiver_alerts',
        builder: (context, state) => const CaregiverAlertsScreen(),
      ),
      GoRoute(
        path: '/medications/add',
        name: 'medications_add',
        builder: (context, state) => const AddMedicationRouteScreen(),
      ),
    ],
  );
}
