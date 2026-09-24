import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/environment.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isSupabaseConfigured = Environment.hasSupabaseConfig;
  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: Environment.supabaseUrl,
      publishableKey: Environment.supabasePublishableKey,
    );
  }
  runApp(BalanceApp(supabaseConfigured: isSupabaseConfigured));
}
