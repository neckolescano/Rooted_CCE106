import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/kuwago_logo.dart';
import '../widgets/owl_mascot.dart';

/// Shown while the app starts up (Firebase, loading your garden).
///
/// The owl mascot perches up top — it breathes, blinks, watches the
/// little plant, and reacts when tapped. Below it, the "loading bar" is a
/// strip of soil where pixel grass grows from left to right; at the
/// growing tip, a plant walks along and grows seed → fully grown.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.progress});

  /// 0.0 – 1.0, how far along start-up is. The bar eases toward it, so
  /// jumps between steps still look smooth.
  final double progress;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  // Drives the little walking bob of the plant.
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat();

  static const _tips = [
    'Watering the seedlings…',
    'Fluffing the soil…',
    'Waking up the sunflowers…',
    'Sweeping the greenhouse…',
  ];

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load all 5 growth stages up front, so switching stage mid-walk is
    // instant instead of waiting on the next image to decode.
    if (!_precached) {
      _precached = true;
      for (final stage in GrassLoadingBar.stages) {
        precacheImage(AssetImage(GrassLoadingBar.stageAsset(stage)), context);
      }
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, p, _) {
                  final tip = _tips[min((p * _tips.length).floor(), _tips.length - 1)];
                  // The owl watches the little plant walk along the grass.
                  final look = p < 0.35 ? -1 : (p > 0.65 ? 1 : 0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The clock "O" spins while loading, then rests.
                      KuwagoLogo(fontSize: 24, ticking: p < 0.999),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '★ ${AppInfo.tagline.toUpperCase()} ★',
                        style: AppTheme.body(size: 13, color: AppColors.greenDeep, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OwlMascot(size: 144, look: look, cheering: p >= 0.999, showHint: true),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        label: 'Loading, ${(p * 100).round()} percent',
                        excludeSemantics: true,
                        child: SizedBox(
                          height: 130,
                          child: AnimatedBuilder(
                            animation: _bob,
                            builder: (context, _) => GrassLoadingBar(progress: p, bob: _bob.value),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(tip, style: AppText.small(color: AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${(p * 100).round()}%', style: AppTheme.pixelHeading(size: 10, color: AppColors.panelMedium)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The grass bar + walking plant. [progress] 0–1, [bob] 0–1 looping.
class GrassLoadingBar extends StatelessWidget {
  const GrassLoadingBar({super.key, required this.progress, required this.bob});

  final double progress;
  final double bob;

  static const stages = ['seed', 'sprout', 'grow', 'bloom', 'fullgrown'];
  static String stageAsset(String stage) => 'assets/images/plant/stages/$stage.png';
  static const double _barHeight = 34; // soil + grass
  static const double _plantSize = 128; // the sprite's real size = crisp

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stage = min((progress * stages.length).floor(), stages.length - 1);
        // Walk: a small hop + tiny sway, only while still loading.
        final hop = progress < 1 ? sin(bob * pi).abs() * 4 : 0.0;
        final sway = progress < 1 ? sin(bob * 2 * pi) * 0.05 : 0.0;
        final tipX = (width * progress).clamp(0.0, width);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: CustomPaint(painter: _GrassPainter(progress)),
            ),
            // The plant rides the growing tip of the grass.
            Positioned(
              left: (tipX - _plantSize / 2).clamp(-_plantSize * 0.25, width - _plantSize * 0.75),
              // Sprites end at row 103 of 128 (~19% empty below the soil),
              // so this sets the plant's soil mound down INTO the soil strip.
              bottom: 5 - _plantSize * 0.19 + hop,
              width: _plantSize,
              height: _plantSize,
              child: Transform.rotate(
                angle: sway,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  stageAsset(stages[stage]),
                  width: _plantSize,
                  height: _plantSize,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Soil strip with pixel grass blades (and a few flowers) that exist only
/// left of the progress point. Blades near the tip are still short —
/// they grow to full height as the tip moves on.
class _GrassPainter extends CustomPainter {
  _GrassPainter(this.progress);

  final double progress;

  static const double px = AppSizes.artScale;
  static const double soilHeight = 12;

  static const _greens = [Color(0xFF74AD50), Color(0xFF508E2A), Color(0xFF0E631A)];
  static const _petals = [Color(0xFFEFD845), Color(0xFFF07AA6), Color(0xFFD2BFF5), Color(0xFFFFF4E0)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final soilTop = h - soilHeight;

    // Soil: dark outline, lit top edge, a few pebbles — the full length
    // is always there (it's the empty "track").
    canvas.drawRect(Rect.fromLTWH(0, soilTop, w, soilHeight), Paint()..color = AppColors.panelDark);
    canvas.drawRect(Rect.fromLTWH(px, soilTop + px, w - px * 2, soilHeight - px * 2), Paint()..color = const Color(0xFF5A3A22));
    canvas.drawRect(Rect.fromLTWH(px, soilTop + px, w - px * 2, px), Paint()..color = const Color(0xFF7A5234));
    for (var x = 10.0; x < w - 10; x += 23) {
      canvas.drawRect(Rect.fromLTWH(x, soilTop + 6, px * 2, px), Paint()..color = const Color(0xFF8A6A4E));
    }

    // Grass up to the progress point.
    final tipX = w * progress;
    final random = Random(3); // fixed = same meadow every launch
    for (var x = px * 2; x < w - px * 2; x += px * 2) {
      final tallness = 8 + random.nextInt(12).toDouble(); // 8–19 dp
      final shade = random.nextInt(_greens.length);
      final flower = random.nextDouble() < 0.07;
      final petal = _petals[random.nextInt(_petals.length)];
      if (x > tipX) continue;

      // Freshly sprouted blades near the tip are shorter.
      final grown = ((tipX - x) / 28).clamp(0.0, 1.0);
      final bladeH = max(px, (tallness * (0.3 + 0.7 * grown) / px).round() * px);
      canvas.drawRect(Rect.fromLTWH(x, soilTop - bladeH, px, bladeH), Paint()..color = _greens[shade]);

      // The odd little flower once the grass there is fully grown.
      if (flower && grown >= 1) {
        final top = soilTop - bladeH - px * 2;
        final paint = Paint()..color = petal;
        canvas.drawRect(Rect.fromLTWH(x - px, top + px, px * 3, px), paint);
        canvas.drawRect(Rect.fromLTWH(x, top, px, px * 3), paint);
        canvas.drawRect(Rect.fromLTWH(x, top + px, px, px), Paint()..color = const Color(0xFFE0C307));
      }
    }
  }

  @override
  bool shouldRepaint(_GrassPainter old) => old.progress != progress;
}
