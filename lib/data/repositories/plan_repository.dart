abstract interface class PlanRepository {
  Future<void> confirm(String changeId);
}
