abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Crash reporting is enabled only when a build supplies SENTRY_DSN.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
