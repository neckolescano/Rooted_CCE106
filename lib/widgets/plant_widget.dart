import 'package:flutter/material.dart';
import '../models/plant_state.dart';

/// Renders the plant for the current [PlantState].
///
/// Tries to load the real pixel-art asset first. If it isn't there
/// yet (you haven't dropped your Piskel export into assets/plant/),
/// it falls back to a simple placeholder so the app is runnable from
/// day one — swap in real art later with zero code changes.
class PlantWidget extends StatelessWidget {
  final PlantState plantState;
  final double size;

  const PlantWidget({super.key, required this.plantState, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        plantState.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // keep pixel art crisp
        errorBuilder: (context, error, stackTrace) => _PlaceholderPlant(
          stage: plantState.stage,
          isWilted: plantState.isWilted,
          size: size,
        ),
      ),
    );
  }
}

class _PlaceholderPlant extends StatelessWidget {
  final PlantStage stage;
  final bool isWilted;
  final double size;

  const _PlaceholderPlant({
    required this.stage,
    required this.isWilted,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isWilted ? Colors.brown.shade300 : Colors.green.shade400;
    // Slightly bigger "plant" the further along the stage is, just so
    // the placeholder gives a visual sense of growth too.
    final fraction = 0.35 + (stage.index / (PlantStage.values.length - 1)) * 0.65;

    return Container(
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWilted ? Icons.eco_outlined : Icons.eco,
            color: baseColor,
            size: size * fraction * 0.6,
          ),
          const SizedBox(height: 8),
          Text(
            isWilted ? '${stage.label} (wilted)' : stage.label,
            style: TextStyle(
              color: baseColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            plantStagePlaceholderHint(stage, isWilted),
            style: TextStyle(color: baseColor.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Points at the exact file this placeholder is standing in for, so
/// it's obvious what to name your Piskel export.
String plantStagePlaceholderHint(PlantStage stage, bool isWilted) {
  final suffix = isWilted ? '_wilted' : '';
  return 'assets/plant/${stage.assetKey}$suffix.png';
}
