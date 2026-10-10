import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/sound_service.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../auth/auth_view_model.dart';
import 'profile_view_model.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/repositories/social_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ProfileViewModel(
      context.read<TaskRepository>(),
      context.read<AvailabilityRepository>(),
      context.read<PlanRepository?>(),
      context.read<RecoveryRepository?>(),
      context.read<ProfileRepository?>(),
      context.read<CheckInRepository?>(),
      context.read<MovementRepository?>(),
      context.read<SocialRepository?>(),
    )..load(),
    child: const _ProfileContent(),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>();
    final auth = context.watch<AuthViewModel>();
    final stressPercent = profile.stressMeterPercent;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: profile.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          _initial(auth.currentUserName, auth.currentUserEmail),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (profile.userProfile?.displayName.isNotEmpty ==
                                          true
                                      ? profile.userProfile!.displayName
                                      : auth.currentUserName) ??
                                  (auth.isConfigured
                                      ? 'Balance member'
                                      : 'Preview user'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.currentUserEmail ??
                                  'No cloud account connected',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        auth.isConfigured
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          auth.isConfigured
                              ? 'Signed in · Changes are saved to your account.'
                              : 'Local preview · Your changes are not saved to Supabase and may disappear when the app closes.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (profile.userProfile != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Planning time zone'),
                    subtitle: Text(profile.userProfile!.timeZone),
                    trailing: profile.isSavingTimeZone
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    onTap: profile.canEditTimeZone && !profile.isSavingTimeZone
                        ? () => _editTimeZone(context, profile)
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Plan summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (profile.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (profile.errorMessage != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.errorMessage!),
                        TextButton(
                          onPressed: profile.load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Active tasks',
                          value: '${profile.plannedTaskCount}',
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Completed tasks',
                          value: '${profile.completedTaskCount}',
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Confirmed plans',
                          value:
                              profile.confirmedPlanCount?.toString() ??
                              'Cloud only',
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Today’s capacity gap',
                          value: '${profile.todayCapacity.overloadMinutes} min',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'World Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stressPercent == null
                              ? 'Not enough data'
                              : '$stressPercent/100${profile.worldStatus.isPartial ? ' · Partial' : ''}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        if (stressPercent != null)
                          LinearProgressIndicator(
                            value: stressPercent / 100,
                            minHeight: 12,
                            borderRadius: BorderRadius.circular(12),
                            color: stressPercent >= 70
                                ? colors.error
                                : colors.primary,
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'The same five-dimension score as Today. Missing data is not zero pressure. Not a health assessment.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _SoundSettings(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Task reminders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.reminders),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: auth.isConfigured && !auth.isLoading
                    ? () async {
                        final signedOut = await auth.signOut();
                        if (!signedOut && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                auth.errorMessage ?? 'Could not sign out.',
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.logout),
                label: Text(auth.isLoading ? 'Signing out…' : 'Sign out'),
              ),
              if (!auth.isConfigured) ...[
                const SizedBox(height: 8),
                const Text(
                  'Sign out is available after connecting Supabase.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String? name, String? email) {
    final source = name ?? email;
    return source == null || source.isEmpty ? 'B' : source[0].toUpperCase();
  }

  Future<void> _editTimeZone(
    BuildContext context,
    ProfileViewModel profile,
  ) async {
    var timeZone = profile.userProfile?.timeZone ?? 'UTC';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Planning time zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use the same time zone as your phone so tasks near midnight appear on the correct day.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: timeZone,
              decoration: const InputDecoration(
                labelText: 'IANA time zone',
                hintText: 'Asia/Kuala_Lumpur',
              ),
              onChanged: (value) => timeZone = value,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, 'Asia/Kuala_Lumpur'),
              child: const Text('Use Malaysia time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, timeZone.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    final saved = await profile.saveTimeZone(selected);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Planning time zone updated.'
              : profile.errorMessage ?? 'Could not update the time zone.',
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

/// Sound toggles; hidden when no [SoundService] is provided (e.g. in tests).
class _SoundSettings extends StatelessWidget {
  const _SoundSettings();

  @override
  Widget build(BuildContext context) {
    final SoundService sound;
    try {
      sound = context.watch<SoundService>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.music_note_outlined),
              title: const Text('Sound effects'),
              subtitle: const Text(
                'Chimes for achievements and confirmed plans',
              ),
              value: sound.effectsOn,
              onChanged: sound.setEffects,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.headphones_outlined),
              title: const Text('Relaxing background music'),
              subtitle: const Text('A calm ambient loop while you plan'),
              value: sound.musicOn,
              onChanged: sound.setMusic,
            ),
          ],
        ),
      ),
    );
  }
}
