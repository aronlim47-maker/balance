import '../enums/energy_level.dart';

class CheckIn {
  const CheckIn({
    required this.date,
    this.id,
    this.sleepHours,
    this.mental,
    this.physical,
    this.social,
    this.errands,
    this.mentalEnergyLevel,
    this.physicalEnergyLevel,
  });

  final String? id;
  final DateTime date;
  final double? sleepHours;
  final int? mental;
  final int? physical;
  final int? social;
  final int? errands;
  final EnergyLevel? mentalEnergyLevel;
  final EnergyLevel? physicalEnergyLevel;
}
