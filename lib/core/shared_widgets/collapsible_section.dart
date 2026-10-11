import 'package:flutter/material.dart';

import '../state/section_memory.dart';
import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';
import 'rpg_widgets.dart';

/// A page section with a large title and a +/− button that shows or hides
/// its content, so pages stay short and easy to scan.
///
/// While closed, an optional [summary] line tells the user what is inside
/// (for example "2 blocks · 4h free"). The open/closed choice is remembered
/// on the phone through [SectionMemoryScope] under [id]; until the user
/// changes it, [initiallyExpanded] decides.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.id,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.summary,
    this.subtitle,
    this.action,
    this.tone = RpgTone.accent,
  });

  /// Storage key, e.g. `today.availability`. Keep it stable.
  final String id;

  /// Section name, shown in capitals.
  final String title;

  final Widget child;
  final bool initiallyExpanded;

  /// Short line shown under the title while the section is closed.
  final String? summary;

  /// Short line always shown under the title (e.g. "Protected").
  final String? subtitle;

  /// Optional small action shown next to the +/− button (e.g. "Add").
  final Widget? action;

  final RpgTone tone;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool? _expanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded ??=
        SectionMemoryScope.maybeOf(context)?.isExpanded(widget.id) ??
        widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different section reusing this slot starts from its own state.
    if (oldWidget.id != widget.id) {
      _expanded =
          SectionMemoryScope.maybeOf(context)?.isExpanded(widget.id) ??
          widget.initiallyExpanded;
    }
  }

  void _toggle() {
    final next = !(_expanded ?? widget.initiallyExpanded);
    setState(() => _expanded = next);
    SectionMemoryScope.maybeOf(context)?.remember(widget.id, next);
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded ?? widget.initiallyExpanded;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final muted = TextStyle(
      fontSize: 14,
      height: 1.3,
      color: BalanceColors.textMuted,
    );
    final header = InkWell(
      // The +/− button below carries the label for screen readers.
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(6),
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      widget.title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: 1.8,
                        height: 1.2,
                        color: widget.tone.foreground,
                      ),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.subtitle!, style: muted),
                  ],
                  if (!expanded && widget.summary != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.summary!, style: muted),
                  ],
                ],
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: 4),
              widget.action!,
            ],
            const SizedBox(width: 4),
            Semantics(
              expanded: expanded,
              child: RpgSquareButton(
                icon: expanded ? Icons.remove : Icons.add,
                tooltip: '${expanded ? 'Hide' : 'Show'} ${widget.title}',
                onPressed: _toggle,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 4),
        const Divider(height: 1),
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
