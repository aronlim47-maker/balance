import 'dart:convert';

import 'package:balance/data/services/planning_read_service.dart';
import 'package:balance/domain/models/local_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late PlanningReadService service;
  late List<http.Request> reads;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() async {
    reads = [];
    respond = (_) async => http.Response('[]', 200);
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
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
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('', 204);
        }
        reads.add(request);
        final response = await respond(request);
        return http.Response(
          response.body,
          response.statusCode,
          request: request,
          headers: {'content-type': 'application/json', ...response.headers},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
    service = PlanningReadService(client);
  });
  tearDown(() async => client.dispose());

  test(
    'snapshot reads bind owner, date boundaries and formula version',
    () async {
      await service.fetchSnapshots(
        from: LocalDate(2026, 9, 21),
        until: LocalDate(2026, 9, 28),
        formulaVersion: 'world_status_v1',
      );
      final request = reads.single;
      expect(request.method, 'GET');
      expect(request.url.queryParameters['user_id'], 'eq.owner-a');
      expect(request.url.queryParametersAll['local_date'], [
        'gte.2026-09-21',
        'lt.2026-09-28',
      ]);
      expect(
        request.url.queryParameters['formula_version'],
        'eq.world_status_v1',
      );
    },
  );

  test('social reads include events crossing the start boundary', () async {
    await service.fetchSocialEvents(
      from: DateTime.utc(2026, 9, 20, 16),
      until: DateTime.utc(2026, 9, 27, 16),
    );
    expect(
      reads.single.url.queryParameters['start_at'],
      'lt.2026-09-27T16:00:00.000Z',
    );
    expect(
      reads.single.url.queryParameters['end_at'],
      'gt.2026-09-20T16:00:00.000Z',
    );
    expect(
      reads.single.url.queryParameters['order'],
      'start_at.asc.nullslast,id.asc.nullslast',
    );
  });

  test('short server pages do not truncate lifetime awards', () async {
    respond = (request) async {
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      if (offset >= 2) return http.Response('[]', 200);
      return http.Response(
        jsonEncode([
          {
            'user_id': 'owner-a',
            'achievement_key': offset == 0 ? 'reflection' : 'safe_trade_off',
            'rule_version': 'achievements_v1',
            'source_event_id': 'event-$offset',
            'occurred_at': '2025-01-01T00:00:00Z',
            'awarded_at': '2025-01-01T00:00:00Z',
          },
        ]),
        200,
      );
    };
    final awards = await service.fetchAchievements();
    expect(awards.length, 2);
    expect(reads.length, 3);
    expect(reads.every((r) => r.method == 'GET'), isTrue);
    expect(
      reads.every((r) => !r.url.queryParameters.containsKey('awarded_at')),
      isTrue,
    );
  });

  test(
    'missing migration errors propagate instead of returning empty data',
    () async {
      respond = (_) async => http.Response(
        jsonEncode({
          'code': 'PGRST205',
          'message': 'table missing',
          'details': null,
          'hint': null,
        }),
        404,
      );
      await expectLater(
        service.fetchAchievements(),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test('sign out during a request discards its result', () async {
    respond = (_) async {
      await client.auth.signOut(scope: SignOutScope.local);
      return http.Response('[]', 200);
    };
    await expectLater(service.fetchAchievements(), throwsStateError);
  });

  test(
    'unauthenticated reads fail before sending a database request',
    () async {
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(service.fetchAchievements(), throwsStateError);
      expect(reads, isEmpty);
    },
  );

  test('invalid ranges and non-Monday weeks never query the server', () async {
    expect(
      () => service.fetchSnapshots(
        from: LocalDate(2026, 9, 28),
        until: LocalDate(2026, 9, 21),
        formulaVersion: 'v1',
      ),
      throwsArgumentError,
    );
    expect(
      () => service.fetchEvents(
        from: DateTime(2026, 9, 21),
        until: DateTime(2026, 9, 28),
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.fetchSocialWeekResponse(LocalDate(2026, 9, 27)),
      throwsArgumentError,
    );
    expect(reads, isEmpty);
  });

  test(
    'no settings or social response stays absent rather than known zero',
    () async {
      expect(await service.fetchSettings(), isNull);
      expect(
        await service.fetchSocialWeekResponse(LocalDate(2026, 9, 21)),
        isNull,
      );
    },
  );

  test(
    'catalogue uses requested version without an owner column filter',
    () async {
      await service.fetchAchievementDefinitions(ruleVersion: 'achievements_v1');
      expect(
        reads.single.url.queryParameters['rule_version'],
        'eq.achievements_v1',
      );
      expect(reads.single.url.queryParameters.containsKey('user_id'), isFalse);
    },
  );
}
