import 'dart:convert';

import 'package:balance/data/services/world_history_service.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late WorldHistoryService service;
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
    service = WorldHistoryService(client);
  });
  tearDown(() async => client.dispose());

  test(
    'week normalizes to Monday and preserves missing and zero scores',
    () async {
      respond = (r) async {
        expect(r.method, 'GET');
        expect(r.url.queryParameters['user_id'], 'eq.owner-a');
        expect(r.url.queryParameters['formula_version'], 'eq.world_status_v1');
        expect(r.url.queryParametersAll['local_date'], [
          'gte.2026-09-28',
          'lte.2026-10-04',
        ]);
        return http.Response(
          jsonEncode([
            {
              'local_date': '2026-09-30',
              'total_score': 42,
              'had_protected_recovery': true,
            },
            {
              'local_date': '2026-09-28',
              'total_score': 0,
              'had_protected_recovery': false,
            },
            {
              'local_date': '2026-10-01',
              'total_score': null,
              'had_protected_recovery': null,
            },
          ]),
          200,
        );
      };
      final week = await service.loadWeek(DateTime(2026, 10, 3));
      expect(week.weekStart, DateTime(2026, 9, 28));
      expect(week.dailyScores, [0, null, 42, null, null, null, null]);
      expect(week.protectedRecoveryDays, 1);
      expect(week.recoveryRecordedDays, 2);
      expect(reads, hasLength(1));
    },
  );

  test(
    'previous seven days exclude selected date across year boundary',
    () async {
      respond = (r) async {
        if (r.url.path.endsWith('/rpc/capture_world_status')) {
          expect(r.method, 'POST');
          return http.Response('null', 200);
        }
        expect(r.url.queryParametersAll['local_date'], [
          'gte.2025-12-29',
          'lte.2026-01-04',
        ]);
        expect(r.url.queryParameters['user_id'], 'eq.owner-a');
        return http.Response(
          '[{"local_date":"2026-01-01","total_score":0}]',
          200,
        );
      };
      expect(await service.loadPreviousWeek(DateTime(2026, 1, 5)), [
        null,
        null,
        null,
        0,
        null,
        null,
        null,
      ]);
      expect(reads, hasLength(2));
    },
  );

  test('missing daily snapshot remains unknown', () async {
    respond = (r) async {
      expect(r.url.queryParameters['local_date'], 'eq.2026-10-03');
      expect(r.url.queryParameters['user_id'], 'eq.owner-a');
      return http.Response('null', 200);
    };
    expect(await service.loadDaySnapshot(DateTime(2026, 10, 3)), isNull);
  });

  test('logout during daily read rejects even a missing result', () async {
    respond = (_) async {
      await client.auth.signOut();
      return http.Response('null', 200);
    };
    await expectLater(
      service.loadDaySnapshot(DateTime(2026, 10, 3)),
      throwsStateError,
    );
  });

  test('logout during weekly read rejects stale history', () async {
    respond = (_) async {
      await client.auth.signOut();
      return http.Response('[]', 200);
    };
    await expectLater(
      service.loadWeek(DateTime(2026, 10, 3)),
      throwsStateError,
    );
  });

  test('logout during capture stops subsequent history request', () async {
    respond = (_) async {
      await client.auth.signOut();
      return http.Response('null', 200);
    };
    await expectLater(
      service.loadPreviousWeek(DateTime(2026, 10, 3)),
      throwsStateError,
    );
    expect(reads, hasLength(1));
    expect(reads.single.url.path, endsWith('/rpc/capture_world_status'));
  });

  test(
    'logout after capture but during history read rejects response',
    () async {
      respond = (r) async {
        if (r.url.path.endsWith('/rpc/capture_world_status')) {
          return http.Response('null', 200);
        }
        await client.auth.signOut();
        return http.Response('[]', 200);
      };
      await expectLater(
        service.loadPreviousWeek(DateTime(2026, 10, 3)),
        throwsStateError,
      );
      expect(reads, hasLength(2));
    },
  );

  test(
    'all history methods reject unauthenticated access before HTTP',
    () async {
      await client.auth.signOut();
      await expectLater(service.loadWeek(DateTime(2026)), throwsStateError);
      await expectLater(
        service.loadPreviousWeek(DateTime(2026)),
        throwsStateError,
      );
      await expectLater(
        service.loadDaySnapshot(DateTime(2026)),
        throwsStateError,
      );
      expect(reads, isEmpty);
    },
  );

  test('server failure is not reported as an empty week', () async {
    respond = (_) async =>
        http.Response('{"code":"42501","message":"denied"}', 403);
    await expectLater(
      service.loadWeek(DateTime(2026)),
      throwsA(isA<PostgrestException>()),
    );
  });
}
