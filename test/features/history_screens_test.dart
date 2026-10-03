import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/data/services/verified_progress_service.dart';
import 'package:balance/domain/enums/plan_status.dart';
import 'package:balance/domain/models/plan_change.dart';
import 'package:balance/domain/models/reflection_record.dart';
import 'package:balance/features/council/plan_history_screen.dart';
import 'package:balance/features/journey/reflection_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('plan history lists confirmed/undone plans but not drafts', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<PlanRepository?>.value(
        value: _Plans(),
        child: const MaterialApp(home: PlanHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Moved reading'), findsOneWidget);
    expect(find.text('Undone task'), findsOneWidget);
    expect(find.text('Draft task'), findsNothing);
  });

  testWidgets('reflection history shows saved content and safe read failures', (
    tester,
  ) async {
    final service = _Reflections();
    await tester.pumpWidget(
      Provider<VerifiedProgressService?>.value(
        value: service,
        child: const MaterialApp(home: ReflectionHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rest helped my planning.'), findsOneWidget);
    service.fail = true;
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Could not load reflections. Try again.'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Plans implements PlanRepository {
  @override
  Future<List<PlanChange>> fetchPlanChanges() async => [
    const PlanChange(
      id: 'one',
      status: PlanStatus.confirmed,
      consequences: {'task_title': 'Moved reading'},
    ),
    const PlanChange(
      id: 'two',
      status: PlanStatus.undone,
      consequences: {'task_title': 'Undone task'},
    ),
    const PlanChange(id: 'three', consequences: {'task_title': 'Draft task'}),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reflections implements VerifiedProgressService {
  bool fail = false;
  @override
  Future<List<ReflectionRecord>> fetchReflections() async {
    if (fail) throw StateError('Do not show technical details');
    return [
      ReflectionRecord(
        body: 'Rest helped my planning.',
        createdAt: DateTime(2026, 10, 3),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
