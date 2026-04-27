import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/medications/add_medication_screen.dart';
import '../../features/medications/medications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/timer/timer_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/timer',
    routes: [
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
        path: '/medications/add',
        name: 'medications_add',
        builder: (context, state) => const AddMedicationRouteScreen(),
      ),
    ],
  );
}
