import 'package:balance/core/utils/app_error_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const fallback = 'Please try again.';

  test('required category gives safe guidance only for its database error', () {
    expect(
      AppErrorMessage.from(
        const PostgrestException(
          message: 'Task category required',
          code: '23514',
        ),
        fallback: fallback,
      ),
      'Choose a task category before saving.',
    );
    expect(
      AppErrorMessage.from(
        const PostgrestException(
          message: 'private constraint details',
          code: '23514',
        ),
        fallback: fallback,
      ),
      'Check the information you entered and try again.',
    );
  });

  test('stale plan version gives a safe refresh instruction', () {
    final message = AppErrorMessage.from(
      const PostgrestException(
        message: 'private task version details',
        code: '40001',
      ),
      fallback: fallback,
    );
    expect(message, contains('Refresh and review'));
    expect(message, isNot(contains('private')));
  });

  test('never exposes an unknown exception', () {
    final message = AppErrorMessage.from(
      Exception('internal database host and stack trace'),
      fallback: fallback,
    );
    expect(message, fallback);
    expect(message, isNot(contains('database host')));
    final databaseMessage = AppErrorMessage.from(
      const PostgrestException(
        message: 'internal table name and query details',
        code: 'XX000',
      ),
      fallback: fallback,
    );
    expect(databaseMessage, fallback);
  });

  test('explains invalid credentials without showing the auth error', () {
    final message = AppErrorMessage.from(
      const AuthException('Invalid login credentials'),
      fallback: fallback,
    );
    expect(message, 'The email or password is incorrect. Try again.');
  });

  test('translates database overlap and time zone errors', () {
    expect(
      AppErrorMessage.from(
        const PostgrestException(message: 'conflicting row', code: '23P01'),
        fallback: fallback,
      ),
      'This time overlaps another item. Choose a different time.',
    );
    expect(
      AppErrorMessage.from(
        const PostgrestException(message: 'Unknown time zone: Mars/Base'),
        fallback: fallback,
      ),
      'Enter a valid time zone, such as Asia/Kuala_Lumpur.',
    );
  });

  test('explains undo conflicts and network failures', () {
    expect(
      AppErrorMessage.from(
        const PostgrestException(
          message:
              'Task changed after this plan; undo would overwrite newer work',
        ),
        fallback: fallback,
      ),
      'This plan cannot be undone because the schedule changed. Review the current plan first.',
    );
    expect(
      AppErrorMessage.from(
        Exception('SocketException: Failed host lookup: private-host'),
        fallback: fallback,
      ),
      'Could not connect. Check your internet connection and try again.',
    );
  });
}
