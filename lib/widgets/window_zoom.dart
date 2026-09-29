import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The "open the window and fly out into the meadow" transition.
///
/// Wrap a whole screen (MainShell, so the nav bar zooms too) in this.
/// Then [zoomThrough] does, in order:
///   1. OPEN   — the window's two halves swing open and the plant ducks
///               into its planter (GreenhouseScene listens to [windowOpen])
///   2. ZOOM   — takes ONE snapshot of the screen and flies the camera
///               through the middle of the window. Moving a single picture
///               is far cheaper than redrawing every widget each frame,
///               which is what keeps it smooth on a phone.
///   3. ARRIVE — part-way through, the next page (the Timer) fades in on
///               top; its background is the same meadow.
/// When that page closes, it all plays backwards: zoom out, then the
/// window shuts and the plant pops back up.
class WindowZoom extends StatefulWidget {
  const WindowZoom({super.key, required this.child});

  final Widget child;

  /// null if there's no WindowZoom above [context].
  static WindowZoomState? maybeOf(BuildContext context) => context.findAncestorStateOfType<WindowZoomState>();

  /// Route for the page behind the window: a soft fade that also settles
  /// from slightly zoomed-in, so the camera move feels like it continues.
  static Route<T> throughWindowRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.06, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WindowZoom> createState() => WindowZoomState();
}

class WindowZoomState extends State<WindowZoom> with TickerProviderStateMixin {
  // ---- Tuning knobs ----
  /// Window swinging open + plant ducking.
  static const openDuration = Duration(milliseconds: 600);

  /// The camera flight through the window.
  static const zoomDuration = Duration(milliseconds: 750);

  /// How far into the flight (0–1) the Timer page starts fading in.
  static const handOffAt = 0.6;

  /// A little extra zoom past "window fills the screen", so the frame
  /// slides fully off the edges.
  static const overshoot = 1.08;

  late final AnimationController _open = AnimationController(vsync: this, duration: openDuration);
  late final AnimationController _zoom = AnimationController(vsync: this, duration: zoomDuration);
  final _boundaryKey = GlobalKey();

  ui.Image? _snapshot;
  Rect? _focus; // the window, in this widget's coordinates
  bool _busy = false;

  /// 0 = window closed, 1 = fully open. GreenhouseScene animates from this.
  Animation<double> get windowOpen => _open;

  @override
  void dispose() {
    _open.dispose();
    _zoom.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Opens the window with [windowKey], flies through it, opens [route],
  /// and plays it all backwards when that route is closed.
  Future<void> zoomThrough(GlobalKey windowKey, Route<void> route) async {
    if (_busy) return;
    final navigator = Navigator.of(context);
    final target = _rectOf(windowKey);

    // Phone set to "remove animations" (accessibility), or the window
    // isn't on screen: just open the page.
    if (target == null || MediaQuery.disableAnimationsOf(context)) {
      // Still guarded: a quick double-tap must not open two Timers (two
      // timers would both grow the plant and record the session twice).
      _busy = true;
      try {
        await navigator.push(route);
      } finally {
        _busy = false;
      }
      return;
    }

    setState(() {
      _busy = true;
      _focus = target;
    });

    // 1. OPEN
    await _open.forward(from: 0);
    if (!mounted) return;

    // 2. ZOOM — freeze the screen (window open, plant tucked away) into
    // one picture and fly that. If the snapshot fails for any reason,
    // the live screen is zoomed instead.
    final snapshot = await _capture();
    if (!mounted) {
      snapshot?.dispose();
      return;
    }
    setState(() => _snapshot = snapshot);
    _zoom.value = 0;
    await _zoom.animateTo(handOffAt);
    if (!mounted) return;
    _zoom.forward();

    // 3. ARRIVE — this await finishes when the Timer page is closed.
    await navigator.push(route);
    if (!mounted) return;

    // Backwards: fly out, drop the snapshot (the live screen underneath
    // looks identical), then close the window.
    await _zoom.reverse();
    if (!mounted) return;
    setState(() {
      _snapshot?.dispose();
      _snapshot = null;
    });
    await _open.reverse();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _focus = null;
    });
  }

  Future<ui.Image?> _capture() async {
    // Wait for the fully-open window to actually be painted.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    try {
      return await boundary.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
    } catch (error) {
      debugPrint('WindowZoom snapshot failed, zooming live instead: $error');
      return null;
    }
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (target == null || me == null || !target.hasSize) return null;
    final topLeft = me.globalToLocal(target.localToGlobal(Offset.zero));
    return topLeft & target.size;
  }

  /// Scale around the window and slide it to the middle of the screen.
  Matrix4 _cameraFor(Rect focus, Size screen, double progress) {
    final t = Curves.easeInOutCubic.transform(progress);
    final fillScale = math.max(screen.width / focus.width, screen.height / focus.height) * overshoot;
    // Growing the scale exponentially (not linearly) makes the camera
    // feel like it's moving at a steady speed instead of lurching.
    final scale = math.pow(fillScale, t).toDouble();
    final from = focus.center;
    final to = Offset.lerp(focus.center, (Offset.zero & screen).center, t)!;

    return Matrix4.translationValues(to.dx, to.dy, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
      ..multiply(Matrix4.translationValues(-from.dx, -from.dy, 0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _zoom,
      child: widget.child,
      builder: (context, child) {
        final focus = _focus;
        final snapshot = _snapshot;
        final camera = focus == null || _zoom.value == 0
            ? Matrix4.identity()
            : _cameraFor(focus, MediaQuery.sizeOf(context), _zoom.value);

        // The widget tree keeps the same shape whether idle or flying,
        // so the tabs underneath never lose their state.
        return IgnorePointer(
          ignoring: _busy, // no double-taps mid-flight
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                key: _boundaryKey,
                // Live zoom only if there's no snapshot to fly instead.
                child: Transform(transform: snapshot == null ? camera : Matrix4.identity(), child: child),
              ),
              if (snapshot != null)
                Transform(
                  transform: camera,
                  child: RawImage(image: snapshot, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
            ],
          ),
        );
      },
    );
  }
}
