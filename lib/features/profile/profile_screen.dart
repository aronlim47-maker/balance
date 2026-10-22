import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/sound_service.dart';
import '../onboarding/onboarding.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../auth/auth_view_model.dart';
import 'profile_avatar.dart';
import 'profile_view_model.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../../core/l10n/tr.dart';

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
      appBar: AppBar(title: Text('Profile'.tr)),
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
                      ProfileAvatar(
                        owner: auth.currentUserId,
                        initial: _initial(
                          _displayName(profile, auth),
                          auth.currentUserEmail,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _displayName(profile, auth) ??
                                        (auth.isConfigured
                                            ? 'Balance member'.tr
                                            : 'Preview user'.tr),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                if (profile.canEditName &&
                                    profile.userProfile != null)
                                  profile.isSavingName
                                      ? const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: 'Edit name'.tr,
                                          onPressed: () =>
                                              _editName(context, profile),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                          ),
                                        ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.currentUserEmail ??
                                  'No cloud account connected'.tr,
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
                                    .tr
                              : 'Local preview · Your changes are not saved to Supabase and may disappear when the app closes.'
                                    .tr,
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
                    title: Text('Planning time zone'.tr),
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
                'Plan summary'.tr,
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
                          child: Text('Try again'.tr),
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
                          label: 'Active tasks'.tr,
                          value: '${profile.plannedTaskCount}',
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Completed tasks'.tr,
                          value: '${profile.completedTaskCount}',
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Confirmed plans'.tr,
                          value:
                              profile.confirmedPlanCount?.toString() ??
                              'Cloud only'.tr,
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Today’s capacity gap'.tr,
                          value:
                              '${profile.todayCapacity.overloadMinutes} min'.tr,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'World Status'.tr,
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
                              ? 'Not enough data'.tr
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
                        Text(
                          'The same five-dimension score as Today. Missing data is not zero pressure. Not a health assessment.'
                              .tr,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text('Beginner guide'.tr),
                  subtitle: Text('Learn Balance in 5 simple steps'.tr),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final route = await showOnboarding(context);
                    if (route != null && context.mounted) context.go(route);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const _SoundSettings(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text('Reminders and alerts'.tr),
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
                                auth.errorMessage ?? 'Could not sign out.'.tr,
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.logout),
                label: Text(auth.isLoading ? 'Signing out…'.tr : 'Sign out'.tr),
              ),
              if (!auth.isConfigured) ...[
                const SizedBox(height: 8),
                Text(
                  'Sign out is available after connecting Supabase.'.tr,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _displayName(ProfileViewModel profile, AuthViewModel auth) {
    final saved = profile.userProfile?.displayName ?? '';
    return saved.isNotEmpty ? saved : auth.currentUserName;
  }

  Future<void> _editName(BuildContext context, ProfileViewModel profile) async {
    // Start from the name shown on the card, so a small change needs no
    // retyping. Empty only when the generic placeholder is showing.
    var name = _displayName(profile, context.read<AuthViewModel>()) ?? '';
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit name'.tr),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          maxLength: ProfileViewModel.maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Display name'.tr),
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name.trim()),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    if (entered == null || !context.mounted) return;
    final saved = await profile.saveDisplayName(entered);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Name updated.'.tr
              : profile.errorMessage ?? 'Could not update your name.'.tr,
        ),
      ),
    );
  }

  static String _initial(String? name, String? email) {
    final source = name ?? email;
    return source == null || source.isEmpty ? 'B'.tr : source[0].toUpperCase();
  }

  Future<void> _editTimeZone(
    BuildContext context,
    ProfileViewModel profile,
  ) async {
    var timeZone = profile.userProfile?.timeZone ?? 'UTC';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Planning time zone'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use the same time zone as your phone so tasks near midnight appear on the correct day.'
                  .tr,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: timeZone,
              decoration: InputDecoration(
                labelText: 'IANA time zone'.tr,
                hintText: 'Asia/Kuala_Lumpur',
              ),
              onChanged: (value) => timeZone = value,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, 'Asia/Kuala_Lumpur'),
              child: Text('Use Malaysia time'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, timeZone.trim()),
            child: Text('Save'.tr),
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
              ? 'Planning time zone updated.'.tr
              : profile.errorMessage ?? 'Could not update the time zone.'.tr,
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
              title: Text('Sound effects'.tr),
              subtitle: Text('Chimes for achievements and confirmed plans'.tr),
              value: sound.effectsOn,
              onChanged: sound.setEffects,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.headphones_outlined),
              title: Text('Relaxing background music'.tr),
              subtitle: Text('A calm ambient loop while you plan'.tr),
              value: sound.musicOn,
              onChanged: sound.setMusic,
            ),
          ],
        ),
      ),
    );
  }
}
