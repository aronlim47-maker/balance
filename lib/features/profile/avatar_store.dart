import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps each account's profile picture on this phone only.
///
/// The picture is already shrunk to at most 512 px when it is picked, so it
/// is small enough (tens of KB) to keep in [SharedPreferences] as text. It
/// is never uploaded; signing in on another phone shows the initial instead.
class AvatarStore {
  const AvatarStore();

  static const keyPrefix = 'balance.avatar.';

  /// [owner] is the signed-in user's id, or null in local preview.
  static String keyFor(String? owner) => '$keyPrefix${owner ?? 'local'}';

  Future<Uint8List?> load(String? owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(keyFor(owner));
      return value == null ? null : base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(String? owner, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(keyFor(owner), base64Encode(bytes));    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(String? owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(keyFor(owner));    } catch (_) {
      return false;
    }
  }
}
