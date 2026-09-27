import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps [child] with a handful of little sparkles that twinkle around
/// it on a loop. Pure code — no extra Piskel art needed. Used behind
/// the plant in the harvest popup to make the achievement feel more
/// celebratory.
class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({
    super.key,
    required this.child,
    this.size = 140,
    this.sparkleCount = 6,
  });

  final Widget child;
  final double size;
  final int sparkleCount;

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _positions; // fractions, can go slightly outside 0..1 to spill past the plant's edges
  late final List<double> _phaseOffsets;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

    // Fixed seed so the sparkle layout is stable instead of jumping
    // around on every rebuild.
    final random = Random(7);
    _positions = List.generate(
      widget.sparkleCount,
      (_) => Offset(random.nextDouble() * 1.4 - 0.2, random.nextDouble() * 1.4 - 0.2),
    );
    _phaseOffsets = List.generate(widget.sparkleCount, (i) => i / widget.sparkleCount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: List.generate(widget.sparkleCount, (i) {
                  // Each sparkle twinkles on its own slice of the shared
                  // loop, so they don't all flash in sync.
                  final t = (_controller.value + _phaseOffsets[i]) % 1.0;
                  // Triangular fade in/out, peaking at the middle of its slice.
                  final opacity = (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
                  final scale = 0.5 + 0.6 * opacity;
                  final pos = _positions[i];

                  return Positioned(
                    left: pos.dx * widget.size - 7,
                    top: pos.dy * widget.size - 7,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(Icons.star_rounded, size: 14, color: AppColors.accentGold),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
