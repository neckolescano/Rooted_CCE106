import 'package:flutter/material.dart';
import '../services/intro_cue.dart';

/// Plays a page's entrance: each [EntranceItem] inside fades and slides
/// into place during its own slice of the entrance.
///
/// On app start it waits until the opening starts revealing the page (see
/// IntroCue); any other time (e.g. right after signing in) it plays at once.
class PageEntrance extends StatefulWidget {
  const PageEntrance({super.key, required this.child, this.duration = const Duration(milliseconds: 1000)});

  final Widget child;
  final Duration duration;

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (IntroCue.stage.value == IntroStage.covering) {
      IntroCue.stage.addListener(_startWhenRevealed);
    } else {
      _controller.forward();
    }
  }

  void _startWhenRevealed() {
    if (IntroCue.stage.value == IntroStage.covering) return;
    IntroCue.stage.removeListener(_startWhenRevealed);
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    IntroCue.stage.removeListener(_startWhenRevealed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceScope(animation: _controller, child: widget.child);
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_EntranceScope old) => old.animation != animation;
}

/// One piece of a [PageEntrance]: appears between [from] and [to] (0–1 of
/// the entrance), sliding in from [slide] dp below (negative = above).
class EntranceItem extends StatelessWidget {
  const EntranceItem({super.key, required this.from, required this.to, this.slide = 24, required this.child});

  final double from, to;
  final double slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = context.dependOnInheritedWidgetOfExactType<_EntranceScope>()?.animation;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = ((animation.value - from) / (to - from)).clamp(0.0, 1.0);
        final move = Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: slide == 0 ? child : Transform.translate(offset: Offset(0, slide * (1 - move)), child: child),
        );
      },
    );
  }
}
