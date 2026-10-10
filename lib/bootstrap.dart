import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/environment.dart';

Future<void> bootstrap() async {
  if (Environment.sentryDsn.isEmpty) return _start();
  await SentryFlutter.init((options) {
    options.dsn = Environment.sentryDsn;
    options.environment = kReleaseMode ? 'production' : 'development';
    // Crash and error reports only: no performance tracing, no screenshots
    // and no personal data (IP, user email) leave the device.
    options.tracesSampleRate = 0;
    options.attachScreenshot = false;
    options.sendDefaultPii = false;
  }, appRunner: _start);
}

Future<void> _start() async {
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
    } catch (error, stackTrace) {
      // No-op when crash reporting is disabled.
      await Sentry.captureException(error, stackTrace: stackTrace);
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
