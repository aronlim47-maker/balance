import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Supabase's `.order(column)` sorts newest first unless `ascending: true` is
/// given, which listed time blocks after a reload from latest to earliest
/// (defect D27). Every primary sort must say its direction; only the `id`
/// tie-breaker may leave it out.
void main() {
  test('every server sort states its direction', () {
    final unstated = <String>[];
    for (final file in Directory('lib/data/services').listSync()) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = RegExp(r"\.order\('(\w+)'\)").firstMatch(lines[i]);
        if (match != null && match.group(1) != 'id') {
          unstated.add('${file.path}:${i + 1} ${lines[i].trim()}');
        }
      }
    }
    expect(unstated, isEmpty);
  });
}
