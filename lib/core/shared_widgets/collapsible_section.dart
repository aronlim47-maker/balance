import 'package:flutter/material.dart';

import '../state/section_memory.dart';
import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';
import 'rpg_widgets.dart';

/// A page section with a large title and a chevron button that shows or hides
/// its content, so pages stay short and easy to scan.
///
/// While closed, an optional [summary] line tells the user what is inside
/// (for example "2 blocks · 4h free"). The open/closed choice is remembered
/// on the phone through [SectionMemoryScope] under [id]; until the user
/// changes it, [initiallyExpanded] decides.
///
/// A [help] text (what the section is for) stays hidden behind a ? button
/// next to the title, so the page shows only what matters at a glance.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.id,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.summary,
    this.help,
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

  /// What the section is for. Hidden until the user taps the ? button.
  final String? help;

  /// Optional small action shown next to the +/− button (e.g. "Add").
  final Widget? action;

  final RpgTone tone;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool? _expanded;
  bool _showHelp = false;

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
                  if (!expanded && widget.summary != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.summary!, style: muted),
                  ],
                ],
              ),
            ),
            if (widget.help != null)
              HelpButton(
                topic: widget.title,
                showing: _showHelp,
                onPressed: () => setState(() => _showHelp = !_showHelp),
              ),
            if (widget.action != null) ...[
              const SizedBox(width: 4),
              widget.action!,
            ],
            const SizedBox(width: 4),
            Semantics(
              expanded: expanded,
              // A chevron, not +/−, so it never reads as "add something".
              child: RpgSquareButton(
                icon: expanded ? Icons.expand_less : Icons.expand_more,
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
        if (widget.help != null && _showHelp)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 52),
            child: Text(widget.help!, style: muted),
          ),
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

/// Round ? button that shows or hides a grey description of [topic].
class HelpButton extends StatelessWidget {
  const HelpButton({
    super.key,
    required this.topic,
    required this.showing,
    required this.onPressed,
  });

  final String topic;
  final bool showing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: showing,
    child: IconButton(
      // "About …" reads naturally for every title ("About What stays
      // protected"), unlike "What is …?".
      tooltip: showing ? 'Hide info about $topic' : 'About $topic',
      onPressed: onPressed,
      color: showing ? BalanceColors.accentBright : BalanceColors.textMuted,
      icon: Icon(showing ? Icons.help : Icons.help_outline, size: 22),
    ),
  );
}
