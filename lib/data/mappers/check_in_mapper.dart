import '../../domain/models/check_in.dart';
import '../../domain/enums/energy_level.dart';

abstract final class CheckInMapper {
  static CheckIn fromJson(Map<String, dynamic> json) => CheckIn(
    id: json['id'] as String?,
    date: DateTime.parse(json['check_in_date'] as String),
    sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
    mental: (json['mental'] as num?)?.toInt(),
    physical: (json['physical'] as num?)?.toInt(),
    social: (json['social'] as num?)?.toInt(),
    errands: (json['errands'] as num?)?.toInt(),
    mentalEnergyLevel: EnergyLevel.fromStorage(
      json['mental_energy_level'] as String?,
    ),
    physicalEnergyLevel: EnergyLevel.fromStorage(
      json['physical_energy_level'] as String?,
    ),
  );

  static Map<String, dynamic> toUpsert(CheckIn checkIn, String userId) => {
    'user_id': userId,
    'check_in_date': dateValue(checkIn.date),
    'sleep_hours': checkIn.sleepHours,
    'mental': checkIn.mental,
    'physical': checkIn.physical,
    'social': checkIn.social,
    'errands': checkIn.errands,
    'mental_energy_level': checkIn.mentalEnergyLevel?.name,
    'physical_energy_level': checkIn.physicalEnergyLevel?.name,
  };

  static String dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
