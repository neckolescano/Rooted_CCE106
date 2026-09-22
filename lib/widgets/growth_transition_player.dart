import 'dart:async';
import 'package:flutter/material.dart';
import '../models/plant_model.dart';

/// Plays the 10 frames for a stage transition (e.g. "sprout" growing into
/// "grow") once, at a fixed speed, then calls [onFinished]. Used on the
/// Timer screen right when a session completes, so the student sees the
/// plant actually grow instead of it just instantly swapping images.
class GrowthTransitionPlayer extends StatefulWidget {
  const GrowthTransitionPlayer({
    super.key,
    required this.transitionKey,
    required this.onFinished,
    this.size = 150,
  });

  final String transitionKey;
  final VoidCallback onFinished;
  final double size;

  @override
  State<GrowthTransitionPlayer> createState() => _GrowthTransitionPlayerState();
}

class _GrowthTransitionPlayerState extends State<GrowthTransitionPlayer> {
  static const _frameDelay = Duration(milliseconds: 90); // ~1.1s for 10 frames

  late final List<String> _framePaths;
  int _frameIndex = 0;
  Timer? _timer;

  // Swapping straight to Image.asset(newPath) on every tick makes Flutter
  // decode each frame from scratch right as it's needed — that decode
  // takes a moment, and during that gap nothing is drawn, which is the
  // "flash" you were seeing. Loading every frame into the image cache
  // BEFORE the animation starts fixes that: by the time we swap frames,
  // they're already decoded and ready to paint instantly.
  bool _framesReady = false;

  @override
  void initState() {
    super.initState();
    _framePaths = PlantModel.framePathsFor(widget.transitionKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_framesReady) {
      _preloadFrames();
    }
  }

  Future<void> _preloadFrames() async {
    await Future.wait(
      _framePaths.map((path) => precacheImage(AssetImage(path), context)),
    );
    if (!mounted) return;
    setState(() => _framesReady = true);
    _timer = Timer.periodic(_frameDelay, _onTick);
  }

  void _onTick(Timer timer) {
    if (_frameIndex >= _framePaths.length - 1) {
      timer.cancel();
      widget.onFinished();
      return;
    }
    setState(() => _frameIndex++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // While the frames are still preloading (should only be a beat),
    // just hold on the first frame instead of showing nothing.
    return Image.asset(
      _framePaths[_framesReady ? _frameIndex : 0],
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      // Keeps the previous frame on screen instead of clearing to blank
      // while the next one paints, in case any decode ever isn't instant.
      gaplessPlayback: true,
    );
  }
}
