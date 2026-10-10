import 'dart:convert';

import 'package:balance/data/services/movement_service.dart';
import 'package:balance/domain/models/movement_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clients may UPDATE only the four setting columns of world_status_settings.
/// An upsert (ON CONFLICT DO UPDATE) also sets user_id and is rejected with
/// "permission denied", so saving must update first and insert only once.
void main() {
  late SupabaseClient client;
  late List<http.Request> writes;
  late bool rowExists;

  const savedRow = {
    'movement_tracking_enabled': true,
    'movement_target_days': 3,
    'target_recovery_minutes': 30,
    'target_social_minutes_week': 300,
  };

  setUp(() async {
    writes = [];
    rowExists = false;
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
        writes.add(request);
        final created = request.method == 'POST';
        final found = created || rowExists;
        if (created) rowExists = true;
        // single() asks for one object; a plain select gets a list.
        final wantsObject = (request.headers['Accept'] ?? '').contains(
          'vnd.pgrst.object',
        );
        return http.Response(
          jsonEncode(wantsObject ? savedRow : [if (found) savedRow]),
          created ? 201 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
  });
  tearDown(() async => client.dispose());

  test(
    'first save inserts the row; no write upserts or updates user_id',
    () async {
      final service = MovementService(client);
      final saved = await service.saveSettings(
        const MovementSettings(trackingEnabled: true),
      );
      expect(saved.trackingEnabled, isTrue);

      expect(writes.map((r) => r.method), ['PATCH', 'POST']);
      final update = writes.first;
      expect(update.url.queryParameters['user_id'], 'eq.owner-a');
      expect(jsonDecode(update.body), isNot(contains('user_id')));
      final insert = writes.last;
      expect(insert.url.queryParameters, isNot(contains('on_conflict')));
      expect(insert.headers['Prefer'] ?? '', isNot(contains('resolution')));
      expect(jsonDecode(insert.body)['user_id'], 'owner-a');
    },
  );

  test('later saves only update the setting columns', () async {
    rowExists = true;
    final service = MovementService(client);
    await service.saveSettings(const MovementSettings(trackingEnabled: true));

    expect(writes.map((r) => r.method), ['PATCH']);
    expect(jsonDecode(writes.single.body), isNot(contains('user_id')));
  });
}
