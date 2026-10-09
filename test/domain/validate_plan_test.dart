import 'package:balance/domain/enums/validation_status.dart';
import 'package:balance/domain/usecases/calculate_capacity.dart';
import 'package:balance/domain/usecases/validate_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// War Council status rules from the Build Phase Plan, section 5:
/// missing information -> Needs Review; unapproved shared changes -> Needs
/// Agreement; impossible constraints -> No Feasible Plan.
///
/// The War Council screens and trade-off generation belong to the War Council
/// owner and have their own tests (generate_trade_offs_test.dart,
/// council_request_regression_test.dart); this file locks the status rules.
void main() {
  ValidationStatus status({
    bool info = true,
    bool capacity = true,
    bool agreement = false,
  }) => validatePlan(
    hasRequiredInformation: info,
    hasFeasibleCapacity: capacity,
    needsAgreement: agreement,
  );

  group('validatePlan status transitions', () {
    test('everything known, feasible and personal is Feasible (Valid)', () {
      expect(status(), ValidationStatus.feasible);
    });

    test('missing information is Needs Review, never success', () {
      expect(status(info: false), ValidationStatus.needsReview);
    });

    test('an unapproved shared change is Needs Agreement', () {
      expect(status(agreement: true), ValidationStatus.needsAgreement);
    });

    test('impossible constraints are No Feasible Plan', () {
      expect(status(capacity: false), ValidationStatus.noFeasiblePlan);
    });
  });

  group('priority when several conditions apply', () {
    test('unknown input wins over everything else', () {
      expect(
        status(info: false, capacity: false, agreement: true),
        ValidationStatus.needsReview,
      );
      expect(
        status(info: false, agreement: true),
        ValidationStatus.needsReview,
      );
      expect(
        status(info: false, capacity: false),
        ValidationStatus.needsReview,
      );
    });

    test('infeasible beats needing agreement', () {
      expect(
        status(capacity: false, agreement: true),
        ValidationStatus.noFeasiblePlan,
      );
    });

    test('all eight input combinations map to exactly one status', () {
      final seen = <ValidationStatus>{};
      for (final info in [true, false]) {
        for (final capacity in [true, false]) {
          for (final agreement in [true, false]) {
            seen.add(
              status(info: info, capacity: capacity, agreement: agreement),
            );
          }
        }
      }
      expect(seen, ValidationStatus.values.toSet());
    });
  });

  group('overload = max(0, planned - available)', () {
    test('acceptance scenario: 300 planned in a 180-minute evening', () {
      expect(
        calculateOverload(plannedMinutes: 300, availableMinutes: 180),
        120,
      );
    });

    test('moving 90 + 60 minutes leaves 150 worked and 30 unallocated', () {
      const planned = 300 - 90 - 60;
      expect(planned, 150);
      expect(
        calculateOverload(plannedMinutes: planned, availableMinutes: 180),
        0,
      );
      expect(180 - planned, 30);
    });

    test('never negative; exact fit is zero; no availability is all of it', () {
      expect(calculateOverload(plannedMinutes: 100, availableMinutes: 180), 0);
      expect(calculateOverload(plannedMinutes: 180, availableMinutes: 180), 0);
      expect(calculateOverload(plannedMinutes: 0, availableMinutes: 0), 0);
      expect(calculateOverload(plannedMinutes: 60, availableMinutes: 0), 60);
    });
  });
}
