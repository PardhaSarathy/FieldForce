import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Fades and lifts its child in once, when it first builds.
///
/// Wrap the *data* branch of an async build. The skeleton is replaced the
/// moment the future resolves either way; this is what stops that being a
/// single-frame swap.
///
/// [delay] staggers a list — see [AppMotion.staggerFor]. Deliberately not a
/// loop or a repeat: it plays once and then the widget is inert, so a rebuild
/// from scrolling or a filter change does not re-animate content that is
/// already on screen.
class Arrive extends StatefulWidget {
  const Arrive({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.rise = AppMotion.rise,
  });

  final Widget child;
  final Duration delay;
  final double rise;

  /// Convenience for a list: `Arrive.staggered(index: i, child: ...)`.
  factory Arrive.staggered({
    Key? key,
    required int index,
    required Widget child,
  }) {
    return Arrive(
      key: key,
      delay: AppMotion.staggerFor(index),
      child: child,
    );
  }

  @override
  State<Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        // The row can be scrolled away and disposed before its turn comes.
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.rise),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Shrinks slightly while held.
///
/// The app had Material's ink splash and nothing else. A splash says the tap
/// registered; a scale says the thing you touched is a physical object, which
/// is the difference this is after. 0.97 is deliberately shallow — anything
/// deeper reads as a toy on a card the size of a quick action.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      // The tap itself stays on whatever the child already uses — an InkWell
      // inside a card keeps its splash and its own callback.
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// A number that counts to its value instead of jumping to it.
///
/// Only for figures a reader watches change — the day's visits, an
/// achievement percentage. A count-up on a static list value is noise.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = AppMotion.slow,
  });

  final double value;
  final Widget Function(BuildContext, double) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // From zero on first build, then from wherever it was — so a refresh
      // that changes 7 to 8 animates one step rather than starting over.
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.curve,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Cross-fades whatever is inside it when the child's identity changes.
///
/// The counterpart to [Arrive]: that animates content the first time it lands,
/// this animates the *change* from one state to another — skeleton to data,
/// data to empty, a filter narrowing a list. Without it the swap happens in a
/// single frame, which is the thing that reads as cheap however well the two
/// states are drawn.
///
/// Give each state a distinct [ValueKey] or the switcher cannot tell them
/// apart and will not animate.
class Swap extends StatelessWidget {
  const Swap({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? AppMotion.normal,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.exitCurve,
      // The default lays the outgoing child over the incoming one, which
      // double-exposes two full screens of content. Fading the new one in over
      // the old is what a dissolve should look like.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Scales in once, for something that arrives on top of settled content — a
/// floating action button, a success mark.
///
/// Distinct from [Arrive] on purpose: a card that lifts into place is joining
/// a page, while this is a thing appearing over one, and the two should not
/// move the same way.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Slight overshoot — the one place in the app that gets any, because a
    // thing landing on top of the page is allowed to have weight.
    final scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return ScaleTransition(
      scale: scale,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}
