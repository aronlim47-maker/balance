import 'dart:convert';

import 'package:balance/data/services/owned_rows.dart';
import 'package:balance/data/services/retry_safe_write.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late Future<http.Response> Function(http.Request) respond;
  setUp(() async {
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
        final response = await respond(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
  });
  tearDown(() async => client.dispose());

  test('short server pages do not truncate 1001 rows', () async {
    var requests = 0;
    respond = (request) async {
      requests++;
      expect(request.url.queryParameters['user_id'], 'eq.owner-a');
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final rows = [
        for (var i = offset; i < offset + 37 && i < 1001; i++) {'id': '$i'},
      ];
      return http.Response(jsonEncode(rows), 200);
    };
    final rows = await readOwnedRows(
      client,
      (owner) => client.from('tasks').select().eq('user_id', owner).order('id'),
    );
    expect(rows, hasLength(1001));
    expect(rows.last['id'], '1000');
    expect(requests, 29);
  });

  test(
    'row limit fails loudly instead of returning a partial result',
    () async {
      respond = (_) async => http.Response('[{"id":"one"},{"id":"two"}]', 200);
      await expectLater(
        readOwnedRows(
          client,
          (owner) =>
              client.from('tasks').select().eq('user_id', owner).order('id'),
          maxRows: 1,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'uncertain writes reuse ID, confirmed identical new writes get new ID',
    () async {
      final writes = RetrySafeWrite();
      final ids = <String>[];
      var fail = true;
      Future<Map<String, dynamic>> write(String id, String owner) async {
        ids.add(id);
        if (fail) {
          fail = false;
          throw StateError('Lost response');
        }
        return {'id': id};
      }

      await expectLater(
        writes.run(client, 'reflection', {'body': 'hello'}, write),
        throwsStateError,
      );
      await writes.run(client, 'reflection', {'body': 'hello'}, write);
      await writes.run(client, 'reflection', {'body': 'hello'}, write);
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
    },
  );

  test('duplicate request recovers the original matching row', () async {
    final writes = RetrySafeWrite();
    Map<String, dynamic>? stored;
    respond = (request) async {
      if (request.method == 'POST') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        if (stored == null) {
          stored = {'id': 'saved', ...payload};
          throw http.ClientException('Lost response');
        }
        expect(payload['request_id'], stored!['request_id']);
        return http.Response('{"code":"23505","message":"duplicate"}', 409);
      }
      return http.Response(jsonEncode(stored), 200);
    };
    await expectLater(
      writes.insert(client, 'reflections', {'body': 'hello'}),
      throwsA(isA<http.ClientException>()),
    );
    final row = await writes.insert(client, 'reflections', {'body': 'hello'});
    expect(row['id'], 'saved');
  });
}
