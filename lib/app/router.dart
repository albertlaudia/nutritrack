import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_motion.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/insights/presentation/screens/insights_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/workout/presentation/screens/workout_screen.dart';
import 'shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => AppMotion.sharedAxisPage(
                  const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                pageBuilder: (context, state) => AppMotion.sharedAxisPage(
                  const WorkoutScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                pageBuilder: (context, state) => AppMotion.sharedAxisPage(
                  const InsightsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => AppMotion.sharedAxisPage(
                  const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        pageBuilder: (context, state) => AppMotion.sharedAxisPage(
          const _CameraPlaceholder(),
        ),
      ),
    ],
  );
});

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: const Center(
        child: Text(
          'Camera screen — capture + AI review flow here',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}