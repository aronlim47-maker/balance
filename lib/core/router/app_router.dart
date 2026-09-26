import 'package:go_router/go_router.dart';

import '../../features/council/plan_updated_screen.dart';
import '../../features/council/war_council_screen.dart';
import '../../features/auth/auth_view_model.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/journey/journey_screen.dart';
import '../../features/quests/quest_board_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/sanctuary/sanctuary_screen.dart';
import '../../features/today/today_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const today = '/today';
  static const quests = '/quests';
  static const council = '/council';
  static const sanctuary = '/sanctuary';
  static const journey = '/journey';
  static const profile = '/profile';
}

GoRouter buildAppRouter(AuthViewModel authViewModel) => GoRouter(
  initialLocation: AppRoutes.today,
  refreshListenable: authViewModel,
  redirect: (_, state) {
    final isAuthPage =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;
    if (!authViewModel.isAuthenticated && !isAuthPage) return AppRoutes.login;
    if (authViewModel.isAuthenticated && isAuthPage) return AppRoutes.today;
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, _) => const RegisterScreen(),
    ),
    GoRoute(path: AppRoutes.today, builder: (_, _) => const TodayScreen()),
    GoRoute(
      path: AppRoutes.quests,
      builder: (_, _) => const QuestBoardScreen(),
    ),
    GoRoute(
      path: AppRoutes.council,
      builder: (_, _) => const WarCouncilScreen(),
    ),
    GoRoute(
      path: '/council/updated/:changeId',
      builder: (_, state) =>
          PlanUpdatedScreen(changeId: state.pathParameters['changeId']!),
    ),
    GoRoute(
      path: AppRoutes.sanctuary,
      builder: (_, _) => const SanctuaryScreen(),
    ),
    GoRoute(path: AppRoutes.journey, builder: (_, _) => const JourneyScreen()),
    GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen()),
  ],
);
