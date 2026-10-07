import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/enums/energy_level.dart';
import '../../domain/models/check_in.dart';

class DailyReviewCard extends StatelessWidget {
  const DailyReviewCard({
    super.key,
    required this.review,
    required this.onEdit,
    required this.isSaving,
  });

  final CheckIn? review;
  final VoidCallback onEdit;
  final bool isSaving;

  @override
  Widget build(BuildContext context) => RpgPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelHeader(
          'Daily Review',
          trailing: RpgTag(
            review == null ? 'Optional' : 'Recorded',
            tone: review == null ? RpgTone.muted : RpgTone.accent,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          review == null
              ? 'Optional'
              : 'Mental: ${review!.mentalEnergyLevel?.label ?? 'Unknown'} · '
                    'Physical: ${review!.physicalEnergyLevel?.label ?? 'Unknown'}',
          style: const TextStyle(color: BalanceColors.textMuted),
        ),
        if (review?.sleepHours != null)
          Text(
            'Rest recorded: ${review!.sleepHours} hours',
            style: const TextStyle(color: BalanceColors.textMuted),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: isSaving ? null : onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(review == null ? 'Add review' : 'Edit review'),
        ),
      ],
    ),
  );
}

class DailyReviewSheet extends StatefulWidget {
  const DailyReviewSheet({super.key, required this.date, this.existing});

  final DateTime date;
  final CheckIn? existing;

  @override
  State<DailyReviewSheet> createState() => _DailyReviewSheetState();
}

class _DailyReviewSheetState extends State<DailyReviewSheet> {
  late EnergyLevel? _mentalEnergy;
  late EnergyLevel? _physicalEnergy;
  late final TextEditingController _sleepController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mentalEnergy = widget.existing?.mentalEnergyLevel;
    _physicalEnergy = widget.existing?.physicalEnergyLevel;
    _sleepController = TextEditingController(
      text: widget.existing?.sleepHours?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _sleepController.dispose();
    super.dispose();
  }

  static const _restPresets = [5, 6, 7, 8];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Eyebrow('Status appraisal'),
          const SizedBox(height: 8),
          const Text(
            'Daily Review',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share only what you want. Skipping does not count as low energy.',
            style: TextStyle(color: BalanceColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          _EnergyChoice(
            label: 'Mental energy',
            hint: 'energy right now',
            value: _mentalEnergy,
            onChanged: (value) => setState(() => _mentalEnergy = value),
          ),
          const SizedBox(height: 12),
          _EnergyChoice(
            label: 'Physical energy',
            hint: 'body right now',
            value: _physicalEnergy,
            onChanged: (value) => setState(() => _physicalEnergy = value),
          ),
          const SizedBox(height: 12),
          RpgPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelHeader('Rest'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final hours in _restPresets) ...[
                      Expanded(
                        child: _RestPreset(
                          label: hours == 8 ? '8h+' : '${hours}h',
                          selected:
                              double.tryParse(_sleepController.text.trim()) ==
                              hours.toDouble(),
                          onTap: () => setState(() {
                            _sleepController.text = hours.toString();
                            _error = null;
                          }),
                        ),
                      ),
                      if (hours != _restPresets.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sleepController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Hours of rest (optional)',
                    hintText: '7.5',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _sleepController.text.trim().isEmpty
                      ? 'Nothing recorded for last night.'
                      : 'Exact hours can be typed above.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: BalanceColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Save review'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final sleepText = _sleepController.text.trim();
    final sleep = sleepText.isEmpty ? null : double.tryParse(sleepText);
    if (sleepText.isNotEmpty && (sleep == null || sleep < 0 || sleep > 24)) {
      setState(() => _error = 'Enter rest hours between 0 and 24.');
      return;
    }
    if (sleep == null && _mentalEnergy == null && _physicalEnergy == null) {
      setState(() => _error = 'Choose an answer or skip for now.');
      return;
    }
    final old = widget.existing;
    Navigator.pop(
      context,
      CheckIn(
        id: old?.id,
        date: widget.date,
        sleepHours: sleep,
        mental: old?.mental,
        physical: old?.physical,
        social: old?.social,
        errands: old?.errands,
        mentalEnergyLevel: _mentalEnergy,
        physicalEnergyLevel: _physicalEnergy,
      ),
    );
  }
}

class _EnergyChoice extends StatelessWidget {
  const _EnergyChoice({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final EnergyLevel? value;
  final ValueChanged<EnergyLevel?> onChanged;

  static String _subtitle(EnergyLevel level) => switch (level) {
    EnergyLevel.low => 'Running on reserves',
    EnergyLevel.moderate => 'Enough for the essentials',
    EnergyLevel.high => 'Room to take something on',
  };

  @override
  Widget build(BuildContext context) => RpgPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          label,
          trailing: Text(
            value == null ? 'Not shared' : hint,
            style: const TextStyle(
              fontSize: 12,
              color: BalanceColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final level in EnergyLevel.values) ...[
          DiamondOptionRow(
            title: level.label,
            subtitle: _subtitle(level),
            selected: value == level,
            // Tapping the chosen level again clears it ("Not shared").
            onTap: () => onChanged(value == level ? null : level),
            trailing: _EnergyBars(level: level, active: value == level),
          ),
          if (level != EnergyLevel.high) const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

class _EnergyBars extends StatelessWidget {
  const _EnergyBars({required this.level, required this.active});
  final EnergyLevel level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = level.index + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 6,
            height: 14,
            margin: const EdgeInsets.only(left: 3),
            color: i < filled
                ? (active ? BalanceColors.accentBright : BalanceColors.accent)
                : BalanceColors.surfaceRaised,
          ),
      ],
    );
  }
}

class _RestPreset extends StatelessWidget {
  const _RestPreset({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Rest $label',
    excludeSemantics: true,
    child: RpgPanel(
      tone: RpgTone.muted,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ),
  );
}
