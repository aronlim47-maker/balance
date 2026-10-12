import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which page sections the user opened or closed, on this phone.
///
/// Values are read once in `bootstrap()` (before the first frame) and kept
/// in memory, so sections open in the right state without a flicker. Each
/// change is also written to [SharedPreferences] under [keyPrefix].
class SectionMemory {
  SectionMemory({Map<String, bool>? initial, this._prefs})
    : _values = {...?initial};

  static const keyPrefix = 'balance.section.';

  final Map<String, bool> _values;
  SharedPreferences? _prefs;

  /// Reads every saved section state. Empty if storage is unavailable.
  static Future<SectionMemory> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = <String, bool>{};
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(keyPrefix)) continue;
        final value = prefs.getBool(key);
        if (value != null) values[key.substring(keyPrefix.length)] = value;
      }
      return SectionMemory(initial: values, prefs: prefs);
    } catch (_) {
      return SectionMemory();
    }
  }

  /// The saved state for [id], or null if the user never changed it.
  bool? isExpanded(String id) => _values[id];

  Future<void> remember(String id, bool expanded) async {
    _values[id] = expanded;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool('$keyPrefix$id', expanded);
    } catch (_) {
      // Best effort: the section still opens and closes for this session.
    }
  }
}

/// Makes [SectionMemory] available to every page section below it.
class SectionMemoryScope extends InheritedWidget {
  const SectionMemoryScope({
    super.key,
    required this.memory,
    required super.child,
  });

  final SectionMemory memory;

  /// The memory, or null when a screen is shown without one (single-screen
  /// widget tests). Sections then use their default state.
  static SectionMemory? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SectionMemoryScope>()?.memory;

  @override
  bool updateShouldNotify(SectionMemoryScope oldWidget) =>
      memory != oldWidget.memory;
}
