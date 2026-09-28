import 'package:flutter/widgets.dart';

/// Where the opening animation is.
enum IntroStage {
  /// The opening covers the app (splash clock, still loading).
  covering,

  /// The opening is revealing the app — pages start their entrance.
  revealing,

  /// The opening is gone; everything is normal.
  done,
}

/// Lets the opening (widgets/clock_intro.dart) and the first page talk:
///
///  * [stage] tells pages when to play their entrance animation, and when
///    to show the pieces the opening "carries in" (hidden until then, so
///    there are never two of them on screen).
///  * The keys mark where those pieces land: the lockup on the login sign,
///    and kuwago's spot on the Home windowsill.
///
/// It starts as [IntroStage.done], so pages opened later (e.g. the login
/// page after signing out) just play their entrance straight away.
class IntroCue {
  IntroCue._();

  static final ValueNotifier<IntroStage> stage = ValueNotifier(IntroStage.done);

  static final GlobalKey loginLockupKey = GlobalKey(debugLabel: 'loginLockup');
  static final GlobalKey homeOwlKey = GlobalKey(debugLabel: 'homeOwl');

  /// Whether the opening is still in front (pages hide carried-in pieces).
  static bool get covering => stage.value != IntroStage.done;

  /// Where [key]'s widget is on screen, or null if it isn't laid out.
  static Rect? rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
