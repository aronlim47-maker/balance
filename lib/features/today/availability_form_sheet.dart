import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/availability_block.dart';

class AvailabilityFormSheet extends StatefulWidget {
  const AvailabilityFormSheet({super.key, required this.day, this.block});

  final DateTime day;
  final AvailabilityBlock? block;

  @override
  State<AvailabilityFormSheet> createState() => _AvailabilityFormSheetState();
}

class _AvailabilityFormSheetState extends State<AvailabilityFormSheet> {
  late final TextEditingController _labelController;
  late DateTime _startAt;
  late DateTime _endAt;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    final block = widget.block;
    _labelController = TextEditingController(text: block?.label ?? '');
    _startAt =
        block?.startAt.toLocal() ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, 9);
    _endAt =
        block?.endAt.toLocal() ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, 17);
    _isAvailable = block?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
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
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.block == null ? 'Add time block' : 'Edit time block',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'Work day',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.event_available),
                label: Text('Available'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.block),
                label: Text('Blocked'),
              ),
            ],
            selected: {_isAvailable},
            onSelectionChanged: (selection) =>
                setState(() => _isAvailable = selection.first),
          ),
          const SizedBox(height: 12),
          _TimeTile(
            label: 'Start',
            value: _startAt,
            onTap: () => _pickTime(isStart: true),
          ),
          const SizedBox(height: 12),
          _TimeTile(
            label: 'End',
            value: _endAt,
            onTap: () => _pickTime(isStart: false),
          ),
          if (!_endAt.isAfter(_startAt)) ...[
            const SizedBox(height: 8),
            Text(
              'End time must be after start time.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _endAt.isAfter(_startAt) ? _submit : null,
            child: Text(
              widget.block == null ? 'Add time block' : 'Save changes',
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = DateTime(
        widget.day.year,
        widget.day.month,
        widget.day.day,
        selected.hour,
        selected.minute,
      );
      if (isStart) {
        _startAt = value;
      } else {
        _endAt = value;
      }
    });
  }

  void _submit() => Navigator.pop(
    context,
    AvailabilityBlock(
      id: widget.block?.id ?? '',
      startAt: _startAt,
      endAt: _endAt,
      isAvailable: _isAvailable,
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(label),
    subtitle: Text(DateFormat.jm().format(value)),
    trailing: const Icon(Icons.schedule),
    onTap: onTap,
  );
}
