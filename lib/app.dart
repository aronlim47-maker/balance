import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/state/planning_day_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/availability_repository.dart';
import 'data/repositories/check_in_repository.dart';
import 'data/repositories/local_planning_repositories.dart';
import 'data/repositories/plan_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/recovery_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/services/availability_service.dart';
import 'data/services/check_in_service.dart';
import 'data/services/plan_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/recovery_service.dart';
import 'data/services/supabase_auth_service.dart';
import 'data/services/task_service.dart';
import 'features/auth/auth_view_model.dart';
import 'features/council/war_council_view_model.dart';

class BalanceApp extends StatefulWidget {
  const BalanceApp({super.key, this.supabaseConfigured = false});

  final bool supabaseConfigured;

  @override
  State<BalanceApp> createState() => _BalanceAppState();
}

class _BalanceAppState extends State<BalanceApp> {
  late final AuthViewModel _authViewModel;
  late final GoRouter _router;
  late final TaskRepository _taskRepository;
  late final AvailabilityRepository _availabilityRepository;
  late final PlanRepository? _planRepository;
  late final RecoveryRepository? _recoveryRepository;
  late final ProfileRepository? _profileRepository;
  late final PlanningDayController _planningDayController;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(
      widget.supabaseConfigured
          ? SupabaseAuthService(Supabase.instance.client)
          : null,
    );
    _taskRepository = widget.supabaseConfigured
        ? TaskService(Supabase.instance.client)
        : LocalTaskRepository();
    _availabilityRepository = widget.supabaseConfigured
        ? AvailabilityService(Supabase.instance.client)
        : LocalAvailabilityRepository();
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
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    _planningDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.supabaseConfigured ? Supabase.instance.client : null;
    return MultiProvider(
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
        Provider<AvailabilityRepository>.value(value: _availabilityRepository),
        Provider<PlanRepository?>.value(value: _planRepository),
        Provider<RecoveryRepository?>.value(value: _recoveryRepository),
        Provider<ProfileRepository?>.value(value: _profileRepository),
        if (client != null) ...[
          Provider<CheckInRepository>.value(value: CheckInService(client)),
        ],
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
