import 'package:flutter/material.dart';

/// Fills the whole screen with a background image (your pixel-art meadow,
/// once it's added) and draws [child] on top of it. If the image file
/// isn't there yet, it falls back to a soft green-to-cream gradient that
/// still looks intentional — so screens don't go back to plain black
/// while you're still drawing the art.
class BackgroundScene extends StatelessWidget {
  const BackgroundScene({
    super.key,
    required this.child,
    this.assetPath = 'assets/images/backgrounds/garden_meadow.png',
  });

  final Widget child;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
