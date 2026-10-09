import 'dart:convert';

import 'package:balance/data/services/achievement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late AchievementService service;
  late String? logoutAt;
  late List<String> reads;
  setUp(() async {
    logoutAt = null;
    reads = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'test-token',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'owner-a',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/auth/v1/logout') return http.Response('', 204);
        reads.add(path);
        if (path == logoutAt) await client.auth.signOut();
        return http.Response(
          path.contains('/rpc/') ? 'null' : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
    service = AchievementService(client);
  });
  tearDown(() async => client.dispose());
  test('normal achievement reads succeed', () async {
    expect((await service.fetchAchievements()).awards, isEmpty);
    expect(reads, hasLength(3));
  });
  for (final path in [
    '/rest/v1/rpc/evaluate_my_achievements',
    '/rest/v1/achievement_definitions',
    '/rest/v1/user_achievements',
  ]) {
    test('logout during $path rejects old account data', () async {
      logoutAt = path;
      await expectLater(service.fetchAchievements(), throwsStateError);
      if (path.contains('/rpc/')) expect(reads, hasLength(1));
    });
  }
  test('unauthenticated read sends no request', () async {
    await client.auth.signOut();
    await expectLater(service.fetchAchievements(), throwsStateError);
    expect(reads, isEmpty);
  });
}
