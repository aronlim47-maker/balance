import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';

/// Converts service and database failures into safe, actionable UI copy.
/// Never return an exception's raw message or details to a user-facing widget.
abstract final class AppErrorMessage {
  /// Shown when a recovery slot is outside every available block, which
  /// almost always means no availability was added for that day yet.
  static final recoveryNeedsAvailability =
      ('Recovery time must be inside your available time. '
              'Add availability on Today first, then try again.')
          .tr;

  /// How long the server asks the user to wait before trying again, when it
  /// says so ("...you can only request this after 42 seconds"). Null otherwise.
  static Duration? retryAfter(Object error) {
    if (error is! AuthException) return null;
    final match = _waitSeconds.firstMatch(error.message.toLowerCase());
    if (match == null) return null;
    return Duration(seconds: int.parse(match.group(1)!));
  }

  static final _waitSeconds = RegExp(r'after (\d+) seconds?');

  static String from(Object error, {required String fallback}) {
    if (error is AuthException) {
      return _auth(
        error.message,
        code: error.code,
        statusCode: error.statusCode,
      );
    }
    if (error is PostgrestException) {
      return _database(error.message, error.code, fallback);
    }
    if (error is TimeoutException) {
      return 'The request took too long. Check your connection and try again.'
          .tr;
    }

    final description = error.toString().toLowerCase();
    if (description.contains('deletion not confirmed')) {
      return 'The deletion could not be confirmed. Refresh the list; the item may already be gone or no longer editable.'
          .tr;
    }
    if (description.contains('task edit conflict')) {
      return 'This task changed or was removed. Refresh the list and review it before saving again.'
          .tr;
    }
    if (_looksLikeNetworkFailure(description)) {
      return 'Could not connect. Check your internet connection and try again.'
          .tr;
    }
    if (description.contains('authentication is required') ||
        description.contains('not authenticated')) {
      return 'Your session has ended. Sign in again and retry.'.tr;
    }
    if (description.contains('not found')) {
      return 'This item is no longer available. Refresh and try again.'.tr;
    }
    return fallback;
  }

  static String _auth(String message, {String? code, String? statusCode}) {
    final detail = message.toLowerCase();
    final wait = _waitSeconds.firstMatch(detail);
    if (wait != null) {
      return ('For security, wait ${wait.group(1)} seconds before trying again. '
              'The button unlocks when the time is up.')
          .tr;
    }
    if (code == 'over_email_send_rate_limit' ||
        detail.contains('email rate limit')) {
      return ('Too many verification emails were sent recently, so new ones are '
              'paused for up to an hour. If you already signed up, check your inbox '
              'and spam folder for the first email, then sign in.')
          .tr;
    }
    if (detail.contains('error sending')) {
      return ('The email could not be sent right now. Wait a few minutes and '
              'try again.')
          .tr;
    }
    if (code == 'signup_disabled' || detail.contains('signups not allowed')) {
      return 'New sign-ups are turned off right now. Please contact the team.'
          .tr;
    }
    if (_looksLikeNetworkFailure(detail)) {
      return 'Could not connect. Check your internet connection and try again.'
          .tr;
    }
    if (detail.contains('invalid login') ||
        detail.contains('invalid credentials') ||
        detail.contains('invalid email or password')) {
      return 'The email or password is incorrect. Try again.'.tr;
    }
    if (detail.contains('email not confirmed') ||
        detail.contains('email not verified')) {
      return 'Verify your email address before signing in.'.tr;
    }
    if (detail.contains('already registered') ||
        detail.contains('already exists')) {
      return 'An account with this email already exists. Sign in instead.'.tr;
    }
    if (detail.contains('invalid email') ||
        detail.contains('email address is invalid')) {
      return 'Enter a valid email address.'.tr;
    }
    if (detail.contains('password') &&
        (detail.contains('weak') ||
            detail.contains('short') ||
            detail.contains('least'))) {
      return 'Choose a stronger password and try again.'.tr;
    }
    if (code == 'over_request_rate_limit' ||
        statusCode == '429' ||
        detail.contains('rate limit') ||
        detail.contains('too many requests')) {
      return ('Too many attempts from this device. Wait about 5 minutes, then '
              'try again.')
          .tr;
    }
    if (detail.contains('expired') || detail.contains('jwt')) {
      return 'Your session has ended. Sign in again and retry.'.tr;
    }
    // Name the server's error code (never its message) so the team can help.
    return code == null
        ? 'Could not complete the account request. Please try again.'.tr
        : ('Could not complete the account request (code: $code). '
                  'Please try again.')
              .tr;
  }

  static String _database(String message, String? code, String fallback) {
    if (code == '40001') {
      return 'This plan changed. Refresh and review it before confirming again.'
          .tr;
    }
    final detail = message.toLowerCase();
    // A row still referenced elsewhere. A delete that also selects the row
    // reports HTTP 409 with the database error JSON as its message, so match
    // the message as well as the code. Plan history keeps every task that was
    // part of a confirmed plan (even after Undo), so it cannot be deleted;
    // completing it removes it from every day instead.
    if (code == '23503' ||
        detail.contains('"23503"') ||
        detail.contains('violates foreign key constraint')) {
      return detail.contains('plan_change_items')
          ? ('This task is part of your plan history, so it cannot be deleted. '
                    'Use Mark as done instead: it will no longer count on any day.')
                .tr
          : 'This item is still used elsewhere, so it cannot be deleted.'.tr;
    }
    if (code == '23514' && detail == 'task category required') {
      return 'Choose a task category before saving.'.tr;
    }
    if (_looksLikeNetworkFailure(detail)) {
      return 'Could not connect. Check your internet connection and try again.'
          .tr;
    }
    if (detail.contains('unknown time zone')) {
      return 'Enter a valid time zone, such as Asia/Kuala_Lumpur.'.tr;
    }
    if (detail.contains('authentication required') ||
        detail.contains('authenticated user')) {
      return 'Your session has ended. Sign in again and retry.'.tr;
    }
    if (detail.contains('agreement')) {
      return 'This task needs agreement before its time can be changed.'.tr;
    }
    if (detail.contains('protected or fixed')) {
      return 'Protected or fixed work cannot be moved automatically.'.tr;
    }
    if (detail.contains('deadline')) {
      return 'Choose a time before the task deadline.'.tr;
    }
    if (detail.contains(
      'duration cannot be less than already allocated work'.tr,
    )) {
      return 'Duration cannot be below already allocated work. Review the plan first.'
          .tr;
    }
    if (detail.contains('undo') ||
        detail.contains('task changed after this plan') ||
        detail.contains('original task time')) {
      return 'This plan cannot be undone because the schedule changed. Review the current plan first.'
          .tr;
    }
    if (detail.contains('committed work') || detail.contains('stranded work')) {
      return 'This time block is used by planned work or recovery. Move those items first.'
          .tr;
    }
    if (detail.contains('recovery slot overlaps')) {
      return 'This recovery time overlaps planned work. Choose a different time.'
          .tr;
    }
    if (detail.contains('overlap') || detail.contains('occupied')) {
      return 'This time overlaps another item. Choose a different time.'.tr;
    }
    if (detail.contains('recovery slot must fit inside available time')) {
      return recoveryNeedsAvailability;
    }
    if (detail.contains('available time') ||
        detail.contains('available block')) {
      return 'Choose a time inside one of your available blocks.'.tr;
    }
    if (detail.contains('overload') || detail.contains('capacity')) {
      return 'This plan does not fit your available time. Review it and try again.'
          .tr;
    }

    return switch (code) {
      '23505' => 'This item already exists. Refresh and check your entries.'.tr,
      '23P01' => 'This time overlaps another item. Choose a different time.'.tr,
      '23514' ||
      '23502' ||
      '22P02' => 'Check the information you entered and try again.'.tr,
      '42501' || 'PGRST301' =>
        'You do not have access to this item. Sign in again and retry.'.tr,
      'PGRST116' =>
        'This item is no longer available. Refresh and try again.'.tr,
      'PGRST202' || 'PGRST204' || '42703' || '42883' =>
        'This feature needs the latest database update. Please contact the project owner.'
            .tr,
      _ => fallback,
    };
  }

  static bool _looksLikeNetworkFailure(String detail) =>
      detail.contains('socketexception') ||
      detail.contains('failed host lookup') ||
      detail.contains('connection refused') ||
      detail.contains('network is unreachable') ||
      detail.contains('connection timed out') ||
      detail.contains('clientexception');
}
