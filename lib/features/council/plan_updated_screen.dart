import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/one_shot.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/shared_widgets/section_header.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/enums/plan_status.dart';
import 'war_council_view_model.dart';
import '../../core/l10n/tr.dart';

class PlanUpdatedScreen extends StatefulWidget {
  const PlanUpdatedScreen({super.key, required this.changeId});
  final String changeId;

  @override
  State<PlanUpdatedScreen> createState() => _PlanUpdatedScreenState();
}

class _PlanUpdatedScreenState extends State<PlanUpdatedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WarCouncilViewModel>().loadChange(widget.changeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WarCouncilViewModel>();
    final change = viewModel.currentChange?.id == widget.changeId
        ? viewModel.currentChange
        : null;
    final hasKnownChange = change != null;
    final isConfirmed =
        change?.status == PlanStatus.confirmed && !viewModel.wasUndone;
    final isUndone =
        hasKnownChange &&
        (change.status == PlanStatus.undone || viewModel.wasUndone);
    final taskTitle =
        change?.consequences['task_title'] as String? ??
        viewModel.confirmedOption?.taskTitle ??
        'Selected task'.tr;
    final movedMinutes =
        (change?.consequences['moved_minutes'] as num?)?.toInt() ??
        viewModel.confirmedOption?.movedMinutes;
    final taskTitles =
        (change?.consequences['task_titles'] as List?)
            ?.whereType<String>()
            .toList() ??
        viewModel.confirmedOption?.allMoves
            .map((move) => move.taskTitle)
            .toList() ??
        const <String>[];
    final taskCount =
        (change?.consequences['task_count'] as num?)?.toInt() ??
        taskTitles.length;
    return Scaffold(
      appBar: AppBar(title: Eyebrow('War Council'.tr), titleSpacing: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (viewModel.isLoadingChange && !hasKnownChange)
              const Center(child: CircularProgressIndicator())
            else
              Align(
                alignment: Alignment.centerLeft,
                // Keyed by outcome, so undoing on this page plays again.
                child: _OutcomeBadge(
                  key: ValueKey(
                    isUndone ? 'undone' : (isConfirmed ? 'confirmed' : 'other'),
                  ),
                  outcome: isUndone
                      ? _Outcome.undone
                      : isConfirmed
                      ? _Outcome.confirmed
                      : _Outcome.other,
                ),
              ),
            const SizedBox(height: 18),
            SectionHeader(
              title: !hasKnownChange
                  ? viewModel.isLoadingChange
                        ? 'Loading plan…'.tr
                        : 'Plan unavailable'.tr
                  : isUndone
                  ? 'Changes were undone'.tr
                  : isConfirmed
                  ? 'Plan confirmed'.tr
                  : 'Plan not confirmed'.tr,
              subtitle: !hasKnownChange
                  ? viewModel.changeNotFound
                        ? 'This plan record could not be found. Return to War Council and refresh.'
                              .tr
                        : 'Check the plan status before making another change.'
                              .tr
                  : isUndone
                  ? '$taskCount task placement${taskCount == 1 ? '' : 's'} restored.'
                        .tr
                  : isConfirmed
                  ? '$taskCount task${taskCount == 1 ? '' : 's'} updated.'.tr
                  : 'No task moves were applied.'.tr,
            ),
            if (isConfirmed || isUndone) ...[
              const SizedBox(height: 18),
              _MoveStrip(
                key: ValueKey(isUndone),
                title: taskTitle,
                reverse: isUndone,
              ),
            ],
            const SizedBox(height: 22),
            if (hasKnownChange)
              RpgPanel(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RpgLabel(
                        isUndone ? 'What was restored'.tr : 'What moved'.tr,
                      ),
                      ListTile(
                        leading: DiamondIcon(
                          size: 12,
                          filled: true,
                          color: isConfirmed
                              ? BalanceColors.accentBright
                              : BalanceColors.textFaint,
                        ),
                        title: Text(taskTitle),
                        subtitle: Text(
                          isUndone
                              ? 'Move reversed'.tr
                              : !isConfirmed
                              ? 'No move applied'.tr
                              : movedMinutes == null
                              ? 'Task placement changed'.tr
                              : '$movedMinutes minutes moved across $taskCount task${taskCount == 1 ? '' : 's'}'
                                    .tr,
                        ),
                      ),
                      for (final title in taskTitles)
                        if (taskTitles.length > 1)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.task_alt),
                            title: Text(title),
                          ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                        ),
                        title: Text(
                          'Change reference'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            color: BalanceColors.textMuted,
                          ),
                        ),
                        subtitle: Text(
                          widget.changeId,
                          style: TextStyle(
                            fontSize: 12,
                            color: BalanceColors.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (viewModel.errorMessage != null) ...[
              Text(
                viewModel.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (!hasKnownChange && !viewModel.isLoadingChange)
              OutlinedButton(
                onPressed: () => viewModel.loadChange(widget.changeId),
                child: Text('Try again'.tr),
              ),
            if (viewModel.canUndoCurrentChange)
              OutlinedButton.icon(
                onPressed: () => _undo(context, viewModel),
                icon: const Icon(Icons.undo),
                label: Text(
                  viewModel.isSaving ? 'Restoring…'.tr : 'Undo this plan'.tr,
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/today'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Return to Today'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _undo(
    BuildContext context,
    WarCouncilViewModel viewModel,
  ) async {
    final undone = await viewModel.undoPlan(widget.changeId);
    if (!context.mounted || (undone && viewModel.refreshWarning == null)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          undone
              ? viewModel.refreshWarning!
              : viewModel.errorMessage ?? 'Undo failed.'.tr,
        ),
      ),
    );
  }
}

enum _Outcome { confirmed, undone, other }

/// Diamond badge at the top of the page. A confirmed plan pops the diamond,
/// draws the tick and throws a few gold sparks; an undone plan spins the
/// undo arrow back into place. Plays once (finished frame with reduced
/// motion).
class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({super.key, required this.outcome});
  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final tone = switch (outcome) {
      _Outcome.confirmed => RpgTone.calm,
      _Outcome.undone => RpgTone.accent,
      _Outcome.other => RpgTone.muted,
    };
    return OneShot(
      duration: const Duration(milliseconds: 1100),
      builder: (context, t) {
        final pop = outcome == _Outcome.other
            ? 1.0
            : phase(t, 0, 0.45, Curves.elasticOut);
        return SizedBox.square(
          dimension: 64,
          child: CustomPaint(
            foregroundPainter: outcome == _Outcome.confirmed
                ? _SparkPainter(phase(t, 0.3, 1))
                : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pop,
                  child: DiamondIcon(
                    size: 60,
                    color: tone.border,
                    strokeWidth: 1.6,
                  ),
                ),
                switch (outcome) {
                  _Outcome.confirmed => CustomPaint(
                    size: const Size.square(26),
                    painter: _TickPainter(
                      phase(t, 0.25, 0.65),
                      tone.foreground,
                    ),
                  ),
                  _Outcome.undone => Transform.rotate(
                    angle: -3.1416 * (1 - phase(t, 0.15, 0.7)),
                    child: Opacity(
                      opacity: phase(t, 0.15, 0.4),
                      child: Icon(
                        Icons.undo_rounded,
                        size: 24,
                        color: tone.foreground,
                      ),
                    ),
                  ),
                  _Outcome.other => Icon(
                    Icons.info_outline,
                    size: 24,
                    color: tone.foreground,
                  ),
                },
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A tick drawn stroke by stroke as [progress] goes from 0 to 1.
class _TickPainter extends CustomPainter {
  _TickPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.78)
      ..lineTo(size.width * 0.88, size.height * 0.24);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.color != color;
}

/// Eight gold sparks that fly out of the badge and fade.
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final paint = Paint()..color = BalanceColors.gold.withValues(alpha: 1 - t);
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.1416 / 4 + 0.2;
      final distance = 30 + 22 * t;
      canvas.drawCircle(
        center + Offset.fromDirection(angle, distance),
        2.6 * (1 - 0.5 * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}

/// "Overloaded day → Day with room": the task chip slides across when a plan
/// is confirmed, and slides back when it is undone.
class _MoveStrip extends StatelessWidget {
  const _MoveStrip({super.key, required this.title, required this.reverse});
  final String title;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    Widget slot(String label, RpgTone tone) => Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BalanceColors.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.border),
        ),
        alignment: Alignment.topLeft,
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: tone.foreground),
        ),
      ),
    );
    return ExcludeSemantics(
      child: OneShot(
        duration: const Duration(milliseconds: 1000),
        builder: (context, t) {
          final move = phase(t, 0.15, 0.8, Curves.easeInOutCubic);
          final p = reverse ? 1 - move : move;
          return LayoutBuilder(
            builder: (context, box) {
              final column = (box.maxWidth - 12) / 2;
              return Stack(
                children: [
                  Row(
                    children: [
                      slot(
                        'Overloaded day'.tr,
                        p < 0.5 ? RpgTone.danger : RpgTone.muted,
                      ),
                      const SizedBox(width: 12),
                      slot('Day with room'.tr, RpgTone.calm),
                    ],
                  ),
                  Positioned(
                    left: 10 + p * (column + 12),
                    width: column - 20,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: BalanceColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BalanceColors.accent),
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
