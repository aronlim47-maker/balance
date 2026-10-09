import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/enums/plan_status.dart';
import '../../domain/models/plan_change.dart';

class PlanHistoryScreen extends StatefulWidget {
  const PlanHistoryScreen({super.key});
  @override
  State<PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

class _PlanHistoryScreenState extends State<PlanHistoryScreen> {
  List<PlanChange> _plans = const [];
  bool _loading = true;
  String? _error;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = context.read<PlanRepository?>();
      final plans = await repository?.fetchPlanChanges() ?? <PlanChange>[];
      if (!mounted || version != _version) return;
      setState(
        () => _plans = plans
            .where((plan) => plan.status != PlanStatus.draft)
            .toList(),
      );
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(
        () => _error = AppErrorMessage.from(
          error,
          fallback: 'Could not load plans. Pull to retry.',
        ),
      );
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plan history')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (!_loading && _error == null && _plans.isEmpty)
            Text(
              context.read<PlanRepository?>() == null
                  ? 'Connect your account to see plan history.'
                  : 'No confirmed plans yet.',
            ),
          for (final plan in _plans)
            Card(
              child: ListTile(
                title: Text(
                  plan.consequences['task_title'] as String? ??
                      'Rebalanced plan',
                ),
                subtitle: Text(
                  '${plan.status == PlanStatus.undone ? 'Undone' : 'Confirmed'}'
                  '${plan.createdAt == null ? '' : ' · ${DateFormat.yMMMd().add_jm().format(plan.createdAt!.toLocal())}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/council/updated/${plan.id}');
                  if (mounted) await _load();
                },
              ),
            ),
        ],
      ),
    ),
  );
}
