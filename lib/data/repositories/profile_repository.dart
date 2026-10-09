import '../../domain/models/app_profile.dart';

abstract interface class ProfileRepository {
  Future<AppProfile> fetchProfile();
  Future<AppProfile> updateTimeZone(String timeZone);
}
