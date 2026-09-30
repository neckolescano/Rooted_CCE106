import 'dart:ui' show Offset;

/// How a scene LOOKS, shared by Garden Scenes and Player Card designs.
///
/// A scene is drawn in three layers (see widgets/garden_scene_backdrop.dart):
///   1. the sky, painted in code: colour bands, drifting clouds, and the
///      sky effects below (sun, moon, stars…);
///   2. the land picture (hills, house, tree, grass) with a see-through
///      sky, drawn by tool/generate_meadow.dart — so the tree and hills
///      are always IN FRONT of the sun and moon;
///   3. the front effects (falling petals, rain, fireflies…).
///
/// Positions like [sunAt] are in "art pixels" of the land picture:
/// 184 wide × 327 tall, the hills' horizon is at about y = 172–188, and
/// the big tree covers x ≥ 132. Keep suns and moons in the clear sky
/// between x = 40 and 125.
class SceneLook {
  const SceneLook({
    required this.sky,
    this.land = SceneLooks.meadowLand,
    this.tint,
    this.clouds,
    this.cloudStyle = CloudStyle.puffy,
    this.effects = const [],
    this.sunAt = const Offset(98, 166),
    this.sunRadius = 18,
    this.moonAt = const Offset(78, 138),
    this.moonRadius = 10,
    this.birdColor = 0xFF4A5A6A,
  });

  /// Sky colours from the top down to the horizon.
  final List<int> sky;

  /// The land picture (see-through sky).
  final String land;

  /// Colour wash multiplied over the land (null = its own colours).
  final int? tint;

  /// Cloud colours: light, mid, shade. null = a clear sky.
  final List<int>? clouds;
  final CloudStyle cloudStyle;

  final List<SceneEffect> effects;

  final Offset sunAt;
  final double sunRadius;
  final Offset moonAt;
  final double moonRadius;
  final int birdColor;
}

enum CloudStyle {
  /// Fluffy cumulus clouds drifting by.
  puffy,

  /// Long thin evening streaks.
  streaks,

  /// Many heavy clouds moving faster (rainy days).
  storm,
}

/// Moving pixel effects. The first group is drawn in the sky (behind the
/// land), the rest in front of it.
enum SceneEffect {
  // --- sky (behind the hills and the tree) ---
  sun,
  sunset, // a big setting sun with glow and turning rays
  moon,
  stars,
  shootingStars,
  aurora,
  rainbow,
  birds,
  lightning,
  // --- in front ---
  petals,
  rain,
  fireflies,
  leaves,
  snow,
  autumnLeaves,
  lanterns,
  goldenMotes, // warm specks of light floating up
  sparkles,
  dust, // blowing sand
  owlEyes,
  windowGlow, // the house windows glow in the dark
  pondShimmer,
}

/// Every look used in the app. Garden Scenes and Card designs pick one.
class SceneLooks {
  SceneLooks._();

  static const meadowLand = 'assets/images/backgrounds/land_meadow.png';
  static const autumnLand = 'assets/images/backgrounds/land_autumn.png';
  static const winterLand = 'assets/images/backgrounds/land_winter.png';
  static const sakuraLand = 'assets/images/backgrounds/land_sakura.png';
  static const desertLand = 'assets/images/backgrounds/land_desert.png';

  static const _daySky = [0xFF6FB8EA, 0xFF84C4EE, 0xFF9DD1F2, 0xFFB8DEF5, 0xFFD4ECF7];
  static const _dayClouds = [0xFFFFFFFF, 0xFFEEF6FB, 0xFFCFE2EF];

  static const meadow = SceneLook(
    sky: _daySky,
    clouds: _dayClouds,
    effects: [SceneEffect.birds],
  );

  static const sunset = SceneLook(
    sky: [0xFF2E2A64, 0xFF553A80, 0xFF8A4A8E, 0xFFC45A86, 0xFFEB7A72, 0xFFF9A45E, 0xFFFFCB6E],
    tint: 0xFFFFB888,
    clouds: [0xFFFFD2A6, 0xFFF28C8C, 0xFFB45A86],
    cloudStyle: CloudStyle.streaks,
    birdColor: 0xFF3A2440,
    effects: [
      SceneEffect.sunset,
      SceneEffect.birds,
      SceneEffect.goldenMotes,
      SceneEffect.windowGlow,
      SceneEffect.pondShimmer,
    ],
  );

  static const cherry = SceneLook(
    sky: [0xFF9FCBEF, 0xFFB5D5F2, 0xFFCADFF3, 0xFFE0E6F2, 0xFFF6E4EC],
    land: sakuraLand,
    clouds: [0xFFFFFFFF, 0xFFFBEFF4, 0xFFEBCFDD],
    effects: [SceneEffect.petals, SceneEffect.birds],
  );

  static const rainy = SceneLook(
    sky: [0xFF56626E, 0xFF636F7B, 0xFF717D89, 0xFF808B96, 0xFF8E98A2],
    tint: 0xFF8497A8, // grey-blue: an overcast, rainy day
    clouds: [0xFFA3ADB7, 0xFF86919C, 0xFF6A7580],
    cloudStyle: CloudStyle.storm,
    effects: [SceneEffect.lightning, SceneEffect.rain],
  );

  static const starry = SceneLook(
    sky: [0xFF0B1030, 0xFF121A44, 0xFF1A2556, 0xFF243268, 0xFF33427A],
    tint: 0xFF4A5AA0,
    clouds: [0xFF3E4A86, 0xFF303C74, 0xFF26305E],
    cloudStyle: CloudStyle.streaks,
    effects: [
      SceneEffect.stars,
      SceneEffect.shootingStars,
      SceneEffect.moon,
      SceneEffect.fireflies,
      SceneEffect.windowGlow,
    ],
  );

  static const forest = SceneLook(
    sky: [0xFF1C2E3A, 0xFF24404A, 0xFF305650, 0xFF476E5A, 0xFF6A8A66],
    tint: 0xFF6E9A66,
    effects: [SceneEffect.stars, SceneEffect.fireflies, SceneEffect.leaves, SceneEffect.windowGlow],
  );

  static const autumn = SceneLook(
    sky: [0xFF78AEDA, 0xFF93BEDF, 0xFFB2CFE2, 0xFFD3DDDF, 0xFFF0E1C8],
    land: autumnLand,
    clouds: [0xFFFFFBF2, 0xFFF4EADB, 0xFFDCCDB8],
    effects: [SceneEffect.birds, SceneEffect.autumnLeaves],
  );

  static const rainbow = SceneLook(
    sky: [0xFF7CC4F0, 0xFF92CEF2, 0xFFAAD9F4, 0xFFC4E4F6, 0xFFDDF0F8],
    tint: 0xFFFFF6E8,
    clouds: _dayClouds,
    effects: [SceneEffect.rainbow, SceneEffect.birds],
  );

  static const lantern = SceneLook(
    sky: [0xFF1C1433, 0xFF2E1F4A, 0xFF462B62, 0xFF6A3872, 0xFF9A4E78],
    tint: 0xFF7A68A0, // purple dusk
    effects: [SceneEffect.stars, SceneEffect.lanterns, SceneEffect.windowGlow],
  );

  static const winter = SceneLook(
    sky: [0xFF93AFCB, 0xFFA5BED6, 0xFFB8CCE0, 0xFFCBDAE8, 0xFFDEE7F0],
    land: winterLand,
    clouds: [0xFFFFFFFF, 0xFFEEF2F7, 0xFFD3DDE8],
    effects: [SceneEffect.snow],
  );

  static const aurora = SceneLook(
    sky: [0xFF040A18, 0xFF08142C, 0xFF0E1E3E, 0xFF15294E, 0xFF1E365E],
    land: winterLand,
    tint: 0xFF7080B0, // snowy polar night
    effects: [SceneEffect.stars, SceneEffect.aurora, SceneEffect.windowGlow],
  );

  static const owlGrove = SceneLook(
    sky: [0xFF06181C, 0xFF0B262C, 0xFF12363C, 0xFF1A4850, 0xFF255A60],
    tint: 0xFF4A7A7E, // moonlit teal
    moonAt: Offset(58, 128),
    moonRadius: 13,
    effects: [
      SceneEffect.stars,
      SceneEffect.moon,
      SceneEffect.fireflies,
      SceneEffect.owlEyes,
      SceneEffect.windowGlow,
    ],
  );

  // --- looks only used by Player Cards ---

  static const desert = SceneLook(
    sky: [0xFF7EC3E6, 0xFF9CCFE6, 0xFFBFDCE0, 0xFFE3E2C8, 0xFFF6DDA8],
    land: desertLand,
    clouds: [0xFFFFFFFF, 0xFFFFF6EA, 0xFFEBDCC6],
    cloudStyle: CloudStyle.streaks,
    sunAt: Offset(84, 138),
    sunRadius: 10,
    effects: [SceneEffect.sun, SceneEffect.dust],
  );

  static const moonlit = SceneLook(
    sky: [0xFF1A1236, 0xFF2A1C4E, 0xFF3C2866, 0xFF52367C, 0xFF6C4890],
    tint: 0xFF7563B8,
    effects: [SceneEffect.stars, SceneEffect.moon, SceneEffect.sparkles, SceneEffect.windowGlow],
  );

  static const golden = SceneLook(
    sky: [0xFFF2B84A, 0xFFF6C862, 0xFFF9D67E, 0xFFFBE29C, 0xFFFDEDBE],
    tint: 0xFFFFE08A,
    clouds: [0xFFFFFBEA, 0xFFFFEFC2, 0xFFF0D08A],
    effects: [SceneEffect.sun, SceneEffect.sparkles],
    sunAt: Offset(92, 150),
    sunRadius: 12,
  );
}
