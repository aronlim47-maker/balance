import 'dart:convert';

import 'package:balance/domain/models/planning_data.dart';

import 'package:balance/data/services/planning_input_service.dart';
import 'package:balance/domain/models/local_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late PlanningInputService service;
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
    service = PlanningInputService(client);
  });
  tearDown(() async => client.dispose());

  const requestId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const taskId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  Future<dynamic> exercise({int minutes = 30}) => service.confirmExercise(
    requestId: requestId,
    occurredAt: DateTime.utc(2026, 9, 28),
    durationMinutes: minutes,
  );
  Map<String, dynamic> exerciseRow() => {
    'id': 'saved',
    'user_id': 'owner-a',
    'request_id': requestId,
    'task_id': null,
    'occurred_at': '2026-09-28T08:00:00+08:00',
    'duration_minutes': 30,
    'intensity': null,
    'source': 'manual',
  };
  http.Response duplicate() => http.Response(
    jsonEncode({'code': '23505', 'message': 'duplicate key'}),
    409,
  );

  test(
    'exercise binds session owner and uses insert, never overwrite',
    () async {
      respond = (r) async {
        expect(r.method, 'POST');
        final body = jsonDecode(r.body) as Map;
        expect(body['user_id'], 'owner-a');
        expect(body['source'], 'manual');
        expect(body['request_id'], requestId);
        expect(r.headers['prefer'], isNot(contains('merge-duplicates')));
        return http.Response(jsonEncode(exerciseRow()), 201);
      };
      final saved = await exercise();
      expect(saved.id, 'saved');
      expect(reads, hasLength(1));
    },
  );

  test(
    'identical duplicate returns original across time zone encodings',
    () async {
      respond = (r) async {
        if (r.method == 'POST') return duplicate();
        expect(r.url.queryParameters['user_id'], 'eq.owner-a');
        expect(r.url.queryParameters['request_id'], 'eq.$requestId');
        return http.Response(jsonEncode(exerciseRow()), 200);
      };
      expect((await exercise()).id, 'saved');
      expect(reads, hasLength(2));
    },
  );

  test('duplicate with changed payload fails without overwrite', () async {
    respond = (r) async => r.method == 'POST'
        ? duplicate()
        : http.Response(jsonEncode(exerciseRow()), 200);
    await expectLater(exercise(minutes: 45), throwsStateError);
    expect(reads.map((r) => r.method), ['POST', 'GET']);
  });

  test('unrelated unique violation propagates', () async {
    respond = (r) async =>
        r.method == 'POST' ? duplicate() : http.Response('null', 200);
    await expectLater(exercise(), throwsA(isA<PostgrestException>()));
  });

  test(
    'RLS or missing migration errors do not become success or retry',
    () async {
      respond = (_) async => http.Response(
        jsonEncode({'code': '42501', 'message': 'permission denied'}),
        403,
      );
      await expectLater(exercise(), throwsA(isA<PostgrestException>()));
      expect(reads, hasLength(1));
    },
  );

  test('logout during insert discards result', () async {
    respond = (_) async {
      await client.auth.signOut();
      return http.Response(jsonEncode(exerciseRow()), 201);
    };
    await expectLater(exercise(), throwsStateError);
  });

  test('unauthenticated writes do not contact tables', () async {
    await client.auth.signOut();
    await expectLater(exercise(), throwsStateError);
    expect(reads, isEmpty);
  });

  test(
    'invalid duration, UUID, local time and empty reflection fail early',
    () async {
      await expectLater(exercise(minutes: 0), throwsArgumentError);
      await expectLater(
        service.confirmExercise(
          requestId: 'bad',
          occurredAt: DateTime.utc(2026),
          durationMinutes: 1,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.confirmExercise(
          requestId: requestId,
          occurredAt: DateTime(2026),
          durationMinutes: 1,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.saveReflection(
          requestId: requestId,
          date: LocalDate(2026, 9, 28),
          content: '  ',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.setSocialWeekResponse(
          weekStart: LocalDate(2026, 9, 29),
          noSocialCommitments: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.confirmSocialEvent(
          requestId: requestId,
          startAt: DateTime.utc(2026),
          endAt: DateTime.utc(2026),
          pressureLevel: EnergyLevel.low,
          hasConflict: null,
        ),
        throwsArgumentError,
      );
      expect(reads, isEmpty);
    },
  );

  test('category patches only owned task and reports missing row', () async {
    respond = (r) async {
      expect(r.method, 'PATCH');
      expect(r.url.queryParameters['user_id'], 'eq.owner-a');
      expect(r.url.queryParameters['id'], 'eq.$taskId');
      expect(jsonDecode(r.body), {'load_category': 'study'});
      return http.Response('[]', 200);
    };
    await expectLater(
      service.setTaskCategory(taskId, LoadCategory.study),
      throwsStateError,
    );
  });

  test(
    'energy patch preserves legacy ratings and clears unknown explicitly',
    () async {
      respond = (r) async {
        expect(r.method, 'PATCH');
        expect(r.url.queryParameters['check_in_date'], 'eq.2026-09-28');
        expect(jsonDecode(r.body), {
          'mental_energy_level': 'low',
          'physical_energy_level': null,
        });
        return http.Response('[{"check_in_date":"2026-09-28"}]', 200);
      };
      await service.saveReviewEnergy(
        date: LocalDate(2026, 9, 28),
        mental: EnergyLevel.low,
        physical: null,
      );
    },
  );

  test('week confirmation is scoped to owner and Monday', () async {
    respond = (r) async {
      expect(jsonDecode(r.body), {
        'user_id': 'owner-a',
        'week_start': '2026-09-28',
        'no_social_commitments': false,
      });
      expect(r.url.queryParameters['on_conflict'], 'user_id,week_start');
      return http.Response('', 204);
    };
    await service.setSocialWeekResponse(
      weekStart: LocalDate(2026, 9, 28),
      noSocialCommitments: false,
    );
  });

  test('overload acknowledgement leaves reviewed_at to database', () async {
    respond = (r) async {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(
        body.keys,
        unorderedEquals(['user_id', 'request_id', 'task_id', 'local_date']),
      );
      return http.Response(jsonEncode({...body, 'id': 'saved'}), 201);
    };
    await service.acknowledgeOverload(
      requestId: requestId,
      taskId: taskId,
      localDate: LocalDate(2026, 9, 28),
    );
  });

  test('reflection preserves text and maps persisted row', () async {
    respond = (r) async => http.Response(
      jsonEncode({
        ...jsonDecode(r.body) as Map<String, dynamic>,
        'id': 'reflection',
        'created_at': '2026-09-28T00:00:00Z',
      }),
      201,
    );
    final saved = await service.saveReflection(
      requestId: requestId,
      date: LocalDate(2026, 9, 28),
      content: ' Rest helped. ',
    );
    expect(saved.content, ' Rest helped. ');
    expect(saved.id, 'reflection');
  });

  test(
    'social confirmation preserves unknown conflict and owned task link',
    () async {
      respond = (r) async => http.Response(
        jsonEncode({
          ...jsonDecode(r.body) as Map<String, dynamic>,
          'id': 'social',
        }),
        201,
      );
      final saved = await service.confirmSocialEvent(
        requestId: requestId,
        taskId: taskId,
        startAt: DateTime.utc(2026, 9, 28),
        endAt: DateTime.utc(2026, 9, 28, 1),
        pressureLevel: EnergyLevel.moderate,
        hasConflict: null,
      );
      expect(saved.hasConflict, isNull);
      expect(saved.taskId, taskId);
      expect(saved.pressureLevel, EnergyLevel.moderate);
    },
  );
}
