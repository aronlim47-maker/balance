// Sanctuary: a recovery slot outside every available block gets a clear
// English message pointing to Today, never the raw database text.
import 'package:balance/core/utils/app_error_message.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/sanctuary/sanctuary_screen.dart';
import 'package:balance/features/sanctuary/sanctuary_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const fallback = 'Please try again.';

  test('server availability error maps to the Today guidance', () {
    final message = AppErrorMessage.from(
      const PostgrestException(
        message: 'Recovery slot must fit inside available time',
        code: 'P0001',
      ),
      fallback: fallback,
    );
    expect(message, AppErrorMessage.recoveryNeedsAvailability);
    expect(message, contains('Add availability on Today first'));
    expect(message, isNot(contains('Recovery slot must')));
  });

  test('recovery overlapping planned work has its own message', () {
    for (final raw in [
      'Recovery slot overlaps a scheduled task',
      'Recovery slot overlaps a moved task',
    ]) {
      expect(
        AppErrorMessage.from(PostgrestException(message: raw), fallback: fallback),
        'This recovery time overlaps planned work. Choose a different time.',
      );
    }
  });

  test('other availability errors keep their existing wording', () {
    expect(
      AppErrorMessage.from(
        const PostgrestException(
          message: 'A scheduled task must fit inside available time',
        ),
        fallback: fallback,
      ),
      'Choose a time inside one of your available blocks.',
    );
  });

  test('saving with no availability sets needsAvailability', () async {
    final repository = _Recovery()
      ..writeError = const PostgrestException(
        message: 'Recovery slot must fit inside available time',
        code: 'P0001',
      );
    final model = SanctuaryViewModel(repository);
    await model.load();

    final saved = await model.save(
      RecoverySlot(
        id: '',
        startAt: DateTime(2026, 10, 9, 20),
        endAt: DateTime(2026, 10, 9, 20, 30),
      ),
    );

    expect(saved, isFalse);
    expect(model.error, AppErrorMessage.recoveryNeedsAvailability);
    expect(model.needsAvailability, isTrue);
    expect(repository.slots, isEmpty);

    repository.writeError = null;
    expect(
      await model.save(
        RecoverySlot(
          id: '',
          startAt: DateTime(2026, 10, 9, 20),
          endAt: DateTime(2026, 10, 9, 20, 30),
        ),
      ),
      isTrue,
    );
    expect(model.needsAvailability, isFalse);
    model.dispose();
  });

  test('an unknown save failure uses the Today-aware fallback', () async {
    final repository = _Recovery()
      ..writeError = StateError('Simulated write failure');
    final model = SanctuaryViewModel(repository);

    expect(
      await model.save(
        RecoverySlot(
          id: '',
          startAt: DateTime(2026, 10, 9, 20),
          endAt: DateTime(2026, 10, 9, 20, 30),
        ),
      ),
      isFalse,
    );
    expect(model.error, contains('available time on Today'));
    expect(model.error, isNot(contains('Simulated')));
    expect(model.needsAvailability, isFalse);
    model.dispose();
  });

  testWidgets('the error panel offers Go to Today', (tester) async {
    final repository = _Recovery()
      ..readError = const PostgrestException(
        message: 'Recovery slot must fit inside available time',
      );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          Provider<RecoveryRepository?>.value(value: repository),
        ],
        child: const MaterialApp(home: SanctuaryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppErrorMessage.recoveryNeedsAvailability),
      findsOneWidget,
    );
    expect(find.text('Go to Today'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class _Recovery implements RecoveryRepository {
  final slots = <RecoverySlot>[];
  Object? readError;
  Object? writeError;

  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async {
    final error = readError;
    if (error != null) throw error;
    return List.of(slots);
  }

  @override
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot) async {
    final error = writeError;
    if (error != null) throw error;
    final saved = RecoverySlot(
      id: 'slot-${slots.length + 1}',
      startAt: slot.startAt,
      endAt: slot.endAt,
      selectedActivity: slot.selectedActivity,
    );
    slots.add(saved);
    return saved;
  }

  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) async {
    slots[slots.indexWhere((item) => item.id == slot.id)] = slot;
    return slot;
  }

  @override
  Future<void> deleteRecoverySlot(String id) async =>
      slots.removeWhere((slot) => slot.id == id);
}
