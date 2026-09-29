/// The user's primary task category. Protection and flexibility are separate.
enum LoadCategory {
  study('Study'),
  errand('Errand'),
  social('Social'),
  exercise('Exercise'),
  other('Other');

  const LoadCategory(this.label);
  final String label;

  static LoadCategory? fromStorage(String? value) => switch (value) {
    'study' => LoadCategory.study,
    'errand' => LoadCategory.errand,
    'social' => LoadCategory.social,
    'exercise' => LoadCategory.exercise,
    'other' => LoadCategory.other,
    _ => null,
  };
}
