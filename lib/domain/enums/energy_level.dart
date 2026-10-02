enum EnergyLevel {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const EnergyLevel(this.label);
  final String label;

  static EnergyLevel? fromStorage(String? value) => switch (value) {
    'low' => EnergyLevel.low,
    'moderate' => EnergyLevel.moderate,
    'high' => EnergyLevel.high,
    _ => null,
  };
}
