import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/user_type_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/onboarding/tutorial_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/timer/timer_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/tasks/add_task_screen.dart';
import '../screens/app_blocker/app_blocker_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/common/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/onboarding');

      if (!isLoggedIn && !isOnAuth) return '/login';
      if (isLoggedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/register' ||
              state.matchedLocation == '/onboarding')) {
        return '/home';
      }
      return null;
    },
    routes: [
      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (ctx, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/user-type',
        builder: (ctx, _) => const UserTypeScreen(),
      ),
      GoRoute(
        path: '/onboarding/permissions',
        builder: (ctx, _) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/tutorial',
        builder: (ctx, _) => const TutorialScreen(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        builder: (ctx, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (ctx, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (ctx, _) => const ProfileScreen(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (ctx, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/timer',
            builder: (ctx, _) => const TimerScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (ctx, _) => const TasksScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (ctx, _) => const AddTaskScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/blocker',
            builder: (ctx, _) => const AppBlockerScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (ctx, _) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (ctx, _) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (ctx, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
