import '../../domain/models/check_in.dart';

abstract interface class CheckInRepository {
  Future<List<CheckIn>> fetchCheckIns();
  Future<CheckIn?> fetchCheckIn(DateTime date);
  Future<CheckIn> saveCheckIn(CheckIn checkIn);
  Future<void> deleteCheckIn(DateTime date);
}
