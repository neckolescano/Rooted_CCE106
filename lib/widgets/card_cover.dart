import 'package:flutter/material.dart';
import '../models/card_designs.dart';
import 'owl_mascot.dart';
import 'pixel_sprite.dart';
import 'scene_frame.dart';

/// The Player Card cover in a given [design]: its scene look (own sky,
/// land and moving effects — the sun and moon sit behind the hills and the
/// tree) and an optional plant or kuwago. Used big on the Profile and small
/// on the design shelf.
class CardCover extends StatelessWidget {
  const CardCover({super.key, required this.design, this.children = const [], this.small = false});

  final CardDesign design;

  /// Extra widgets on top (e.g. the "PLAYER CARD" tag).
  final List<Widget> children;

  /// Shelf thumbnail: smaller decorations.
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      look: design.look,
      animate: !small,
      // A little more sky than the middle, with the house still in view.
      imageAlignment: const Alignment(0, -0.08),
      golden: design.golden,
      children: [
        // The plant stands in the field on the right, clear of the house
        // (left) and the avatar (centre).
        if (design.sprite != null)
          Positioned(
            right: small ? 2 : 64,
            bottom: small ? -6 : -12,
            child: PixelSprite(design.sprite!, size: small ? 40 : 72, zoom: 1.2),
          ),
        if (design.owl)
          Positioned(
            right: small ? 4 : 12,
            bottom: small ? 0 : 2,
            child: OwlSprite(size: small ? 24 : 48, perch: false),
          ),
        ...children,
      ],
    );
  }
}
