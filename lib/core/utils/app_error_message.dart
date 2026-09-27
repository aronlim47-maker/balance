import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts service and database failures into safe, actionable UI copy.
/// Never return an exception's raw message or details to a user-facing widget.
abstract final class AppErrorMessage {
  static String from(Object error, {required String fallback}) {
    if (error is AuthException) return _auth(error.message);
    if (error is PostgrestException) {
      return _database(error.message, error.code, fallback);
    }
    if (error is TimeoutException) {
      return 'The request took too long. Check your connection and try again.';
    }

    final description = error.toString().toLowerCase();
    if (_looksLikeNetworkFailure(description)) {
      return 'Could not connect. Check your internet connection and try again.';
    }
    if (description.contains('authentication is required') ||
        description.contains('not authenticated')) {
      return 'Your session has ended. Sign in again and retry.';
    }
    if (description.contains('not found')) {
      return 'This item is no longer available. Refresh and try again.';
    }
    return fallback;
  }

  static String _auth(String message) {
    final detail = message.toLowerCase();
    if (_looksLikeNetworkFailure(detail)) {
      return 'Could not connect. Check your internet connection and try again.';
    }
    if (detail.contains('invalid login') ||
        detail.contains('invalid credentials') ||
        detail.contains('invalid email or password')) {
      return 'The email or password is incorrect. Try again.';
    }
    if (detail.contains('email not confirmed') ||
        detail.contains('email not verified')) {
      return 'Verify your email address before signing in.';
    }
    if (detail.contains('already registered') ||
        detail.contains('already exists')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (detail.contains('invalid email') ||
        detail.contains('email address is invalid')) {
      return 'Enter a valid email address.';
    }
    if (detail.contains('password') &&
        (detail.contains('weak') ||
            detail.contains('short') ||
            detail.contains('least'))) {
      return 'Choose a stronger password and try again.';
    }
    if (detail.contains('rate limit') || detail.contains('too many requests')) {
      return 'Too many attempts. Wait a little and try again.';
    }
    if (detail.contains('expired') || detail.contains('jwt')) {
      return 'Your session has ended. Sign in again and retry.';
    }
    return 'Could not complete the account request. Please try again.';
  }

  static String _database(String message, String? code, String fallback) {
    final detail = message.toLowerCase();
    if (_looksLikeNetworkFailure(detail)) {
      return 'Could not connect. Check your internet connection and try again.';
    }
    if (detail.contains('unknown time zone')) {
      return 'Enter a valid time zone, such as Asia/Kuala_Lumpur.';
    }
    if (detail.contains('authentication required') ||
        detail.contains('authenticated user')) {
      return 'Your session has ended. Sign in again and retry.';
    }
    if (detail.contains('agreement')) {
      return 'This task needs agreement before its time can be changed.';
    }
    if (detail.contains('protected or fixed')) {
      return 'Protected or fixed work cannot be moved automatically.';
    }
    if (detail.contains('deadline')) {
      return 'Choose a time before the task deadline.';
    }
    if (detail.contains('undo') ||
        detail.contains('task changed after this plan') ||
        detail.contains('original task time')) {
      return 'This plan cannot be undone because the schedule changed. Review the current plan first.';
    }
    if (detail.contains('committed work') || detail.contains('stranded work')) {
      return 'This time block is used by planned work or recovery. Move those items first.';
    }
    if (detail.contains('overlap') || detail.contains('occupied')) {
      return 'This time overlaps another item. Choose a different time.';
    }
    if (detail.contains('available time') ||
        detail.contains('available block')) {
      return 'Choose a time inside one of your available blocks.';
    }
    if (detail.contains('overload') || detail.contains('capacity')) {
      return 'This plan does not fit your available time. Review it and try again.';
    }

    return switch (code) {
      '23505' => 'This item already exists. Refresh and check your entries.',
      '23P01' => 'This time overlaps another item. Choose a different time.',
      '23514' ||
      '23502' ||
      '22P02' => 'Check the information you entered and try again.',
      '42501' || 'PGRST301' =>
        'You do not have access to this item. Sign in again and retry.',
      'PGRST116' => 'This item is no longer available. Refresh and try again.',
      'PGRST202' || 'PGRST204' || '42703' || '42883' => 'This feature needs the latest database update. Please contact the project owner.',
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
