import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/supabase_auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(
      widget.supabaseConfigured
          ? SupabaseAuthService(Supabase.instance.client)
          : null,
    );
    _router = buildAppRouter(_authViewModel);
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _authViewModel),
      ChangeNotifierProvider(create: (_) => WarCouncilViewModel()),
    ],
    child: MaterialApp.router(
      title: 'Balance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    ),
  );
}
