import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/environment.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isSupabaseConfigured = Environment.hasSupabaseConfig;
  if (!isSupabaseConfigured && kReleaseMode) {
    runApp(
      const _StartupMessage(
        message: 'Balance needs its Supabase project URL and publishable key. Rebuild the release app with --dart-define-from-file=.env.',
      ),
    );
    return;
  }
  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Environment.supabaseUrl,
        publishableKey: Environment.supabasePublishableKey,
      );
    } catch (_) {
      runApp(
        const _StartupMessage(
          message: 'Balance could not start its account service. Check your connection and app configuration, then reopen the app.',
        ),
      );
      return;
    }
  }
  runApp(BalanceApp(supabaseConfigured: isSupabaseConfigured));
}

class _StartupMessage extends StatelessWidget {
  const _StartupMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
}
