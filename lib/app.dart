import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/state/planning_day_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/availability_repository.dart';
import 'data/repositories/achievement_repository.dart';
import 'data/repositories/local_achievement_repository.dart';
import 'data/repositories/check_in_repository.dart';
import 'data/repositories/local_planning_repositories.dart';
import 'data/repositories/movement_repository.dart';
import 'data/repositories/plan_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/recovery_repository.dart';
import 'data/repositories/social_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/services/availability_service.dart';
import 'data/services/achievement_service.dart';
import 'data/services/check_in_service.dart';
import 'data/services/movement_service.dart';
import 'data/services/plan_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/recovery_service.dart';
import 'data/services/social_service.dart';
import 'data/services/supabase_auth_service.dart';
import 'data/services/task_service.dart';
import 'features/auth/auth_view_model.dart';
import 'features/council/war_council_view_model.dart';
import 'data/repositories/world_history_repository.dart';
import 'data/services/world_history_service.dart';
import 'data/services/verified_progress_service.dart';

class BalanceApp extends StatefulWidget {
  const BalanceApp({super.key, this.supabaseConfigured = false});

  final bool supabaseConfigured;

  @override
  State<BalanceApp> createState() => _BalanceAppState();
}

class _BalanceAppState extends State<BalanceApp> {
  late final AuthViewModel _authViewModel;
  late final AchievementRepository _achievementRepository;
  late final GoRouter _router;
  late final TaskRepository _taskRepository;
  late final CheckInRepository _checkInRepository;
  late final MovementRepository _movementRepository;
  late final SocialRepository _socialRepository;
  late final AvailabilityRepository _availabilityRepository;
  late final PlanRepository? _planRepository;
  late final RecoveryRepository? _recoveryRepository;
  late final ProfileRepository? _profileRepository;
  late final PlanningDayController _planningDayController;
  String? _sessionUserId;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(
      widget.supabaseConfigured
          ? SupabaseAuthService(Supabase.instance.client)
          : null,
    );
    _achievementRepository = widget.supabaseConfigured
        ? AchievementService(Supabase.instance.client)
        : LocalAchievementRepository();
    _taskRepository = widget.supabaseConfigured
        ? TaskService(Supabase.instance.client)
        : LocalTaskRepository();
    _availabilityRepository = widget.supabaseConfigured
        ? AvailabilityService(Supabase.instance.client)
        : LocalAvailabilityRepository();
    _checkInRepository = widget.supabaseConfigured
        ? CheckInService(Supabase.instance.client)
        : LocalCheckInRepository();
    _movementRepository = widget.supabaseConfigured
        ? MovementService(Supabase.instance.client)
        : LocalMovementRepository();
    _socialRepository = widget.supabaseConfigured
        ? SocialService(Supabase.instance.client)
        : LocalSocialRepository();
    _planRepository = widget.supabaseConfigured
        ? PlanService(Supabase.instance.client)
        : null;
    _recoveryRepository = widget.supabaseConfigured
        ? RecoveryService(Supabase.instance.client)
        : null;
    _profileRepository = widget.supabaseConfigured
        ? ProfileService(Supabase.instance.client)
        : null;
    _planningDayController = PlanningDayController();
    _router = buildAppRouter(_authViewModel);
    _sessionUserId = _authViewModel.currentUserId;
    _authViewModel.addListener(_handleAccountChange);
  }

  void _handleAccountChange() {
    final userId = _authViewModel.currentUserId;
    if (!mounted || userId == _sessionUserId) return;
    _planningDayController.selectDay(DateTime.now());
    setState(() => _sessionUserId = userId);
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.removeListener(_handleAccountChange);
    _authViewModel.dispose();
    _planningDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      key: ValueKey(_sessionUserId),
      providers: [
        ChangeNotifierProvider.value(value: _authViewModel),
        ChangeNotifierProvider.value(value: _planningDayController),
        ChangeNotifierProvider(
          create: (_) => WarCouncilViewModel(
            _taskRepository,
            _availabilityRepository,
            _planningDayController,
            _planRepository,
            _recoveryRepository,
          ),
        ),
        Provider<TaskRepository>.value(value: _taskRepository),
        Provider<AchievementRepository>.value(value: _achievementRepository),
        Provider<CheckInRepository>.value(value: _checkInRepository),
        Provider<MovementRepository>.value(value: _movementRepository),
        Provider<SocialRepository>.value(value: _socialRepository),
        Provider<AvailabilityRepository>.value(value: _availabilityRepository),
        Provider<PlanRepository?>.value(value: _planRepository),
        Provider<RecoveryRepository?>.value(value: _recoveryRepository),
        Provider<ProfileRepository?>.value(value: _profileRepository),
        Provider<WorldHistoryRepository?>(
          create: (_) => widget.supabaseConfigured
              ? WorldHistoryService(Supabase.instance.client)
              : null,
        ),
        Provider<VerifiedProgressService?>(
          create: (_) => widget.supabaseConfigured
              ? VerifiedProgressService(Supabase.instance.client)
              : null,
        ),
      ],
      child: MaterialApp.router(
        title: 'Balance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
