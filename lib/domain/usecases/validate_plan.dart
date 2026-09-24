import '../enums/validation_status.dart';

ValidationStatus validatePlan({
  required bool hasRequiredInformation,
  required bool hasFeasibleCapacity,
  required bool needsAgreement,
}) {
  if (!hasRequiredInformation) return ValidationStatus.needsReview;
  if (!hasFeasibleCapacity) return ValidationStatus.noFeasiblePlan;
  return needsAgreement
      ? ValidationStatus.needsAgreement
      : ValidationStatus.feasible;
}
