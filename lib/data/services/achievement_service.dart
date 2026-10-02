import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/achievement_models.dart';
import '../repositories/achievement_repository.dart';
import 'authenticated_user.dart';

class AchievementService implements AchievementRepository {
  AchievementService(this._client);

  final SupabaseClient _client;

  @override
  Future<AchievementSnapshot> fetchAchievements() async {
    final userId = requireAuthenticatedUserId(_client);
    await _client.rpc('evaluate_my_achievements');
    final definitionsFuture = _client
        .from('achievement_definitions')
        .select(
          'achievement_key,practical_name,rpg_name,condition_text,display_order',
        )
        .eq('rule_version', 'achievement_v1')
        .order('display_order');
    final awardsFuture = _client
        .from('user_achievements')
        .select('achievement_key,awarded_at')
        .eq('user_id', userId)
        .eq('rule_version', 'achievement_v1');
    final definitions = await definitionsFuture;
    final awards = await awardsFuture;
    return AchievementSnapshot(
      definitions: definitions
          .map(
            (row) => AchievementDefinition(
              key: row['achievement_key'] as String,
              practicalName: row['practical_name'] as String,
              rpgName: row['rpg_name'] as String,
              condition: row['condition_text'] as String,
              order: (row['display_order'] as num).toInt(),
            ),
          )
          .toList(growable: false),
      awards: awards
          .map(
            (row) => AchievementAward(
              key: row['achievement_key'] as String,
              awardedAt: DateTime.parse(row['awarded_at'] as String),
            ),
          )
          .toList(growable: false),
    );
  }
}
