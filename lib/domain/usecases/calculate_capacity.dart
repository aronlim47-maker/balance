int calculateOverload({
  required int plannedMinutes,
  required int availableMinutes,
}) => (plannedMinutes - availableMinutes).clamp(0, plannedMinutes).toInt();
