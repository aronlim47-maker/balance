import '../../core/l10n/tr.dart';

enum EnergyLevel {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const EnergyLevel(this._english);
  final String _english;

  /// The label in the current language.
  String get label => _english.tr;

  static EnergyLevel? fromStorage(String? value) => switch (value) {
    'low' => EnergyLevel.low,
    'moderate' => EnergyLevel.moderate,
    'high' => EnergyLevel.high,
    _ => null,
  };
}
