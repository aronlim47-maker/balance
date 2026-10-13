import 'package:flutter/material.dart';

/// Plays a short animation once and hands its progress (0 → 1) to [builder].
///
/// It replays when [replayKey] changes (for example when the day's numbers
/// change), and shows the finished frame straight away when the phone asks
/// for reduced motion. Nothing loops, so screens settle and stay calm.
class OneShot extends StatefulWidget {
  const OneShot({
    super.key,
    required this.duration,
    required this.builder,
    this.replayKey,
    this.delay = Duration.zero,
  });

  final Duration duration;
  final Duration delay;
  final Object? replayKey;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<OneShot> createState() => _OneShotState();
}

class _OneShotState extends State<OneShot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(OneShot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) _play();
  }

  void _play() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final total = widget.delay + widget.duration;
      final lead = total.inMicroseconds == 0
          ? 0.0
          : widget.delay.inMicroseconds / total.inMicroseconds;
      final raw = _controller.value;
      final t = raw <= lead ? 0.0 : (raw - lead) / (1 - lead);
      return widget.builder(context, t.clamp(0.0, 1.0));
    },
  );
}

/// Progress of [t] within [begin]–[end], eased with [curve].
double phase(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

/// Fades and lifts [child] into place once, like a card being dealt.
class EntranceFade extends StatelessWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => OneShot(
    duration: const Duration(milliseconds: 380),
    delay: delay,
    builder: (context, t) {
      final p = Curves.easeOutCubic.transform(t);
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - p)),
          child: child,
        ),
      );
    },
  );
}
