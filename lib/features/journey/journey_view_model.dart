import '../../core/state/lifecycle_notifier.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/achievement_repository.dart';
import '../../domain/models/achievement_models.dart';
import '../../data/repositories/world_history_repository.dart';

class JourneyViewModel extends LifecycleNotifier {
  JourneyViewModel(this._repository, [this._history]);

  final AchievementRepository _repository;
  final WorldHistoryRepository? _history;
  DateTime _weekStart = _monday(DateTime.now());
  int _loadVersion = 0;
  WeeklyJourney? _week;
  String? _weekError;
  WeeklyJourney? get week => _week;
  String? get weekError => _weekError;
  DateTime get weekStart => _weekStart;
  Future<void> shiftWeek(int weeks) async {
    if (isDisposed) return;
    _week = null;
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + weeks * 7,
    );
    await load();
  }

  static DateTime _monday(DateTime day) =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);
  List<AchievementDefinition> _definitions = achievementV1Catalogue;
  Map<String, AchievementAward> _awards = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<AchievementDefinition> get definitions =>
      List.unmodifiable(_definitions);
  AchievementAward? awardFor(String key) => _awards[key];
  int get unlockedCount => _awards.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get reflectionSavedMessage =>
      _errorMessage != null || _weekError != null
      ? 'Reflection saved, but the latest view could not refresh. Pull to retry.'
      : 'Reflection saved.';

  Future<void> load() async {
    if (isDisposed) return;
    final version = ++_loadVersion;
    final loadingWeek = _weekStart;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _repository.fetchAchievements();
      if (version != _loadVersion) return;
      final remoteByKey = {
        for (final definition in snapshot.definitions)
          definition.key: definition,
      };
      _definitions = [
        for (final definition in achievementV1Catalogue)
          remoteByKey[definition.key] ?? definition,
      ]..sort((a, b) => a.order.compareTo(b.order));
      _awards = {
        for (final award in snapshot.awards)
          if (_definitions.any((definition) => definition.key == award.key))
            award.key: award,
      };
    } catch (error) {
      if (version != _loadVersion) return;
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not load achievements. Pull to retry.',
      );
    } finally {
      if (_history != null && !isDisposed && version == _loadVersion) {
        try {
          final loadedWeek = await _history.loadWeek(loadingWeek);
          if (version != _loadVersion) return;
          _week = loadedWeek;
          _weekError = null;
        } catch (error) {
          if (version != _loadVersion) return;
          _week = null;
          _weekError = AppErrorMessage.from(
            error,
            fallback: 'Could not load this week. Pull to retry.',
          );
        }
      }
      if (version == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    ++_loadVersion;
    super.dispose();
  }
}
