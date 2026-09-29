import 'package:flutter/material.dart';
import '../models/garden_scenes.dart';
import 'garden_scene_backdrop.dart';

/// Fills the whole screen with a background image (your pixel-art meadow)
/// and draws [child] on top of it. If the image file isn't there, it falls
/// back to a soft green-to-cream gradient that still looks intentional —
/// so screens don't go back to plain black.
///
/// Pass a [scene] to show the meadow in that Garden Scene instead (colour
/// wash + moving effects) — the Timer does this with the equipped scene.
class BackgroundScene extends StatelessWidget {
  const BackgroundScene({
    super.key,
    required this.child,
    this.assetPath = 'assets/images/backgrounds/garden_meadow.png',
    this.scene,
  });

  final Widget child;
  final String assetPath;
  final GardenScene? scene;

  @override
  Widget build(BuildContext context) {
    final scene = this.scene;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (scene != null)
          GardenSceneBackdrop(scene: scene, pixel: 2)
        else
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none, // keeps pixel art crisp
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFAFD8C9), Color(0xFFF3E8D2)],
                  ),
                ),
              );
            },
          ),
        child,
      ],
    );
  }
}
