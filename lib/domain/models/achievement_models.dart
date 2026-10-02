class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.practicalName,
    required this.rpgName,
    required this.condition,
    required this.order,
  });

  final String key;
  final String practicalName;
  final String rpgName;
  final String condition;
  final int order;
}

class AchievementAward {
  const AchievementAward({required this.key, required this.awardedAt});

  final String key;
  final DateTime awardedAt;
}

class AchievementSnapshot {
  const AchievementSnapshot({required this.definitions, required this.awards});

  final List<AchievementDefinition> definitions;
  final List<AchievementAward> awards;
}

/// Matches the achievement_v1 catalogue in the applied SQL migration.
const achievementV1Catalogue = <AchievementDefinition>[
  AchievementDefinition(
    key: 'protected_rest',
    practicalName: 'Protected Rest',
    rpgName: 'Sanctuary Keeper',
    condition: 'Protect a sleep or recovery slot.',
    order: 1,
  ),
  AchievementDefinition(
    key: 'safe_trade_off',
    practicalName: 'Safe Trade-off',
    rpgName: 'Wise Strategist',
    condition: 'Confirm a plan without breaking protected commitments.',
    order: 2,
  ),
  AchievementDefinition(
    key: 'deadline_safety',
    practicalName: 'Deadline Safety',
    rpgName: 'Deadline Guardian',
    condition: 'Move a flexible task while keeping its deadline safe.',
    order: 3,
  ),
  AchievementDefinition(
    key: 'early_review',
    practicalName: 'Early Review',
    rpgName: 'Early Scout',
    condition: 'Review an overload before the deadline day.',
    order: 4,
  ),
  AchievementDefinition(
    key: 'protected_limit',
    practicalName: 'Protected Limit',
    rpgName: 'Contract Keeper',
    condition: 'Protect a work shift, family duty or sleep minimum.',
    order: 5,
  ),
  AchievementDefinition(
    key: 'reflection',
    practicalName: 'Reflection',
    rpgName: 'Camp Journal Entry',
    condition: 'Save a completed optional reflection.',
    order: 6,
  ),
  AchievementDefinition(
    key: 'team_coordination',
    practicalName: 'Team Coordination',
    rpgName: 'Team Navigator',
    condition: 'Mark a shared task as Needs Agreement without moving it.',
    order: 7,
  ),
];
