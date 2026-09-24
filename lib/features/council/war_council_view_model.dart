import 'package:flutter/foundation.dart';

class TradeOffOption {
  const TradeOffOption({
    required this.id,
    required this.title,
    required this.description,
    required this.movedMinutes,
    required this.recoveryMinutes,
    this.needsAgreement = false,
  });

  final String id;
  final String title;
  final String description;
  final int movedMinutes;
  final int recoveryMinutes;
  final bool needsAgreement;
}

class WarCouncilViewModel extends ChangeNotifier {
  WarCouncilViewModel()
    : options = const [
        TradeOffOption(
          id: 'balanced-shift',
          title: 'Move research to tomorrow',
          description: 'Move 150 minutes of flexible work and protect a 30-minute recovery slot tonight.',
          movedMinutes: 150,
          recoveryMinutes: 30,
        ),
        TradeOffOption(
          id: 'shared-shift',
          title: 'Reschedule the group review',
          description: 'Move 90 minutes, but wait for the other members to agree before confirming.',
          movedMinutes: 90,
          recoveryMinutes: 0,
          needsAgreement: true,
        ),
      ];

  final List<TradeOffOption> options;
  String? _selectedOptionId = 'balanced-shift';
  bool _isSaving = false;
  bool _wasUndone = false;

  String? get selectedOptionId => _selectedOptionId;
  bool get isSaving => _isSaving;
  bool get wasUndone => _wasUndone;
  TradeOffOption? get selectedOption =>
      options.where((option) => option.id == _selectedOptionId).firstOrNull;
  bool get canConfirm =>
      selectedOption != null && !selectedOption!.needsAgreement && !_isSaving;

  void selectOption(String id) {
    _selectedOptionId = id;
    notifyListeners();
  }

  Future<String> confirmSelectedPlan() async {
    if (!canConfirm) throw StateError('The selected plan cannot be confirmed.');
    _isSaving = true;
    _wasUndone = false;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _isSaving = false;
    notifyListeners();
    return 'local-${DateTime.now().millisecondsSinceEpoch}';
  }

  void undoPlan() {
    _wasUndone = true;
    notifyListeners();
  }
}
