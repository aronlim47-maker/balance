import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            review == null
                ? 'Optional'
                : 'Mental: ${review!.mentalEnergyLevel?.label ?? 'Unknown'} · '
                      'Physical: ${review!.physicalEnergyLevel?.label ?? 'Unknown'}',
          ),
          if (review?.sleepHours != null)
            Text('Rest recorded: ${review!.sleepHours} hours'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: isSaving ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: Text(review == null ? 'Add review' : 'Edit review'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Daily Review',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Share only what you want. Skipping does not count as low energy.',
          ),
          const SizedBox(height: 16),
          _EnergyChoice(
            label: 'Mental energy',
            value: _mentalEnergy,
            onChanged: (value) => setState(() => _mentalEnergy = value),
          ),
          const SizedBox(height: 12),
          _EnergyChoice(
            label: 'Physical energy',
            value: _physicalEnergy,
            onChanged: (value) => setState(() => _physicalEnergy = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sleepController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hours of rest (optional)',
              hintText: '7.5',
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
          FilledButton(onPressed: _save, child: const Text('Save review')),
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
    required this.value,
    required this.onChanged,
  });

  final String label;
  final EnergyLevel? value;
  final ValueChanged<EnergyLevel?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<EnergyLevel?>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<EnergyLevel?>(
        value: null,
        child: Text('Not shared'),
      ),
      for (final level in EnergyLevel.values)
        DropdownMenuItem<EnergyLevel?>(value: level, child: Text(level.label)),
    ],
    onChanged: onChanged,
  );
}
