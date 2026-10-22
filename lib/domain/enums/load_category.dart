import '../../core/l10n/tr.dart';

/// The user's primary task category. Protection and flexibility are separate.
enum LoadCategory {
  study('Study'),
  errand('Errand'),
  social('Social'),
  exercise('Exercise'),
  other('Other');

  const LoadCategory(this._english);
  final String _english;

  /// The label in the current language.
  String get label => _english.tr;

  static LoadCategory? fromStorage(String? value) => switch (value) {
    'study' => LoadCategory.study,
    'errand' => LoadCategory.errand,
    'social' => LoadCategory.social,
    'exercise' => LoadCategory.exercise,
    'other' => LoadCategory.other,
    _ => null,
  };
}
