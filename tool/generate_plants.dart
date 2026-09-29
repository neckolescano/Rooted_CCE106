// Generates pixel-art growth sprites for the extra garden plants, in the
// same style as the hand-drawn Wild Sunflower:
//   * 128x128 canvas, plant standing on the SAME soil mound (copied from
//     your sunflower seed.png), soil surface at row 92
//   * 1-pixel black outline around every shape
//   * 4-step colour ramps (light → dark) with lit top-left edges and
//     shaded bottom-right edges
//   * 5 stages + 4 transitions × 10 frames, same file names as the sunflower
//
// Run from the project root:
//   dart run tool/generate_plants.dart
//
// Output: assets/images/plants/<plant_id>/stages/*.png and frames/*.png
// Feel free to open any output in Piskel and touch it up by hand.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const size = 128;
const ground = 92; // soil surface row (same as the sunflower)
const baseX = 64; // where stems leave the soil

// ---------------------------------------------------------------------------
// Colour ramps: index 0 = lightest … 3 = darkest
// ---------------------------------------------------------------------------

const outlineColor = 0xFF000000;

class Ramp {
  const Ramp(this.colors, {this.shaded = true, this.outlined = true});
  final List<int> colors;
  final bool shaded; // gets lit/shadow edges
  final bool outlined; // gets a black outline
}

// The sunflower's own leaf greens, so every plant shares the family look.
const leafGreen = Ramp([0xFF74AD50, 0xFF508E2A, 0xFF0E631A, 0xFF0B3812]);
const cactusGreen = Ramp([0xFF9CCB6B, 0xFF5E9E48, 0xFF35753A, 0xFF1D4A26]);
const fernGreen = Ramp([0xFF8CCB5E, 0xFF55A33C, 0xFF2F7430, 0xFF184A1E]);
const pink = Ramp([0xFFFFC2D9, 0xFFF07AA6, 0xFFC04C7C, 0xFF7E2A52]);
const sunYellow = Ramp([0xFFEFD845, 0xFFE0C307, 0xFFAD9602, 0xFF72640B]);
const lavender = Ramp([0xFFF7F3FF, 0xFFD2BFF5, 0xFFA283DC, 0xFF6A4BAA]);
const spine = Ramp([0xFFFFF6DE, 0xFFF3E3B8, 0xFFD9C28E, 0xFFB39A66], shaded: false);
const spore = Ramp([0xFFD9A04A, 0xFFB07A2E, 0xFF8A5A1E, 0xFF5E3C12], shaded: false);
const glow = Ramp([0xFFE8FBFF, 0xFFBFF3FF, 0xFF8FE3F5, 0xFF5CC8E0], shaded: false, outlined: false);
// Legendary / Mythic / Glory plants.
const fire = Ramp([0xFFFFF3B0, 0xFFFFC23D, 0xFFF27A1A, 0xFFB8321A]);
const crimson = Ramp([0xFFFF8A7A, 0xFFE0413A, 0xFFA8232E, 0xFF6A1424]);
const ember = Ramp([0xFFFFFBE0, 0xFFFFE27A, 0xFFFFB347, 0xFFF27A1A], shaded: false, outlined: false);
const lotusWhite = Ramp([0xFFFFFFFF, 0xFFE6EEFF, 0xFFB9C8F5, 0xFF8A8FDC]);
const crystal = Ramp([0xFFEFFAFF, 0xFF9CCBFF, 0xFF6A8CF0, 0xFF4B4FC8], shaded: false);
const bark = Ramp([0xFFC89A5A, 0xFF9A6B38, 0xFF6E4722, 0xFF432A14]);
const goldLeaf = Ramp([0xFFFFF3B8, 0xFFF5CC4C, 0xFFC8962A, 0xFF8A6418]);
const goldGlow = Ramp([0xFFFFFFFF, 0xFFFFF4B0, 0xFFFFE066, 0xFFFFC928], shaded: false, outlined: false);

// ---------------------------------------------------------------------------
// A drawing layer: each pixel remembers its ramp + shade level, so the
// outline and edge-shading passes can run after everything is drawn.
// ---------------------------------------------------------------------------

class Layer {
  final ramps = List<Ramp?>.filled(size * size, null);
  final levels = List<int>.filled(size * size, 0);

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;
  bool filled(int x, int y) => inside(x, y) && ramps[y * size + x] != null;

  void set(int x, int y, Ramp ramp, int level) {
    if (!inside(x, y) || y > ground) return;
    ramps[y * size + x] = ramp;
    levels[y * size + x] = level.clamp(0, 3);
  }

  void clear(int x, int y) {
    if (inside(x, y)) ramps[y * size + x] = null;
  }

  void disc(double cx, double cy, double r, Ramp ramp, int level) {
    for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
      for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
        final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        if (dx * dx + dy * dy <= r * r) set(x, y, ramp, level);
      }
    }
  }

  void ellipse(double cx, double cy, double rx, double ry, Ramp ramp, int level) {
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) set(x, y, ramp, level);
      }
    }
  }

  void rect(int x0, int y0, int x1, int y1, Ramp ramp, int level) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, ramp, level);
      }
    }
  }

  void line(double x0, double y0, double x1, double y1, Ramp ramp, int level, {double width = 1}) {
    final steps = math.max(1, (math.max((x1 - x0).abs(), (y1 - y0).abs()) * 2).ceil());
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
      if (width <= 1) {
        set(x.floor(), y.floor(), ramp, level);
      } else {
        disc(x, y, width / 2, ramp, level);
      }
    }
  }

  /// Lit top/left edges, shaded bottom/right edges — the same trick the
  /// hand-drawn leaves use.
  void shadeEdges() {
    final newLevels = List<int>.from(levels);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final ramp = ramps[y * size + x];
        if (ramp == null || !ramp.shaded) continue;
        bool same(int nx, int ny) => inside(nx, ny) && ramps[ny * size + nx] == ramp;
        var level = levels[y * size + x];
        if (!same(x, y - 1) || !same(x - 1, y)) level -= 1;
        if (!same(x, y + 1) || !same(x + 1, y)) level += 1;
        newLevels[y * size + x] = level.clamp(0, 3);
      }
    }
    levels.setAll(0, newLevels);
  }
}

// ---------------------------------------------------------------------------
// Plant shapes
// ---------------------------------------------------------------------------

/// A leaf blade along a gentle curve: widest in the middle, pointed at
/// both ends, with a darker midrib. Returns the midrib points.
List<List<double>> blade(Layer l, double x, double y, double angleDeg, double length, double width, Ramp ramp,
    {double bend = 0}) {
  var a = angleDeg * math.pi / 180;
  var px = x, py = y;
  final points = <List<double>>[];
  for (var i = 0; i <= length; i++) {
    points.add([px, py]);
    a += bend * math.pi / 180 / length;
    px += math.sin(a);
    py -= math.cos(a);
  }
  for (var i = 0; i < points.length; i++) {
    final t = i / (points.length - 1);
    final w = width * math.sin(math.pi * math.min(1, t * 1.15)) + 0.6;
    l.disc(points[i][0], points[i][1], w / 2, ramp, 1);
  }
  for (var i = 1; i < points.length * 0.8; i++) {
    l.set(points[i][0].floor(), points[i][1].floor(), ramp, 2);
  }
  return points;
}

/// A plain stem (slightly curved), dark in the middle.
List<List<double>> stem(Layer l, double x, double y, double length, {double lean = 0, double width = 2}) {
  final points = <List<double>>[];
  for (var i = 0; i <= length; i++) {
    final t = i / length;
    final px = x + lean * math.sin(t * math.pi / 2);
    final py = y - i;
    points.add([px, py]);
    l.line(px, py, px + width - 1, py, leafGreen, 2);
  }
  return points;
}

// --- Desert Cactus ---------------------------------------------------------

/// Upright cactus column with a rounded top, two ribs and spine dots.
void cactusBody(Layer l, int x0, int x1, int top, {int bottom = ground}) {
  final w = x1 - x0 + 1;
  for (var y = top; y <= bottom; y++) {
    final inset = y == top ? 2 : (y == top + 1 ? 1 : 0);
    for (var x = x0 + inset; x <= x1 - inset; x++) {
      final rel = (x - x0) / (w - 1);
      l.set(x, y, cactusGreen, rel < 0.25 ? 0 : (rel < 0.7 ? 1 : 2));
    }
  }
  if (w >= 11) {
    for (final rx in [x0 + w ~/ 3, x0 + 2 * w ~/ 3]) {
      for (var y = top + 3; y <= bottom; y++) {
        l.set(rx, y, cactusGreen, 2);
      }
    }
  }
}

void cactusArm(Layer l, int bodyEdge, int attachY, int dir, int outLen, int upLen, {int thick = 7}) {
  // sideways part
  final xa = dir < 0 ? bodyEdge - outLen : bodyEdge;
  final xb = dir < 0 ? bodyEdge : bodyEdge + outLen;
  l.rect(xa, attachY, xb, attachY + thick - 1, cactusGreen, 1);
  // upright part at the outer end, rounded top
  final ux0 = dir < 0 ? xa : xb - thick + 1;
  cactusBody(l, ux0, ux0 + thick - 1, attachY - upLen, bottom: attachY + thick - 1);
}

void spines(Layer l, int x0, int x1, int top, {int bottom = ground, int every = 5}) {
  for (var y = top + 3; y < bottom - 1; y += every) {
    l.set(x0 + 1, y, spine, 0);
    l.set(x1 - 1, y + 2, spine, 0);
    if (x1 - x0 > 10) l.set((x0 + x1) ~/ 2, y + 1, spine, 1);
  }
}

void cactusFlower(Layer l, double cx, double cy, double r) {
  for (var k = 0; k < 5; k++) {
    final a = -math.pi / 2 + k * 2 * math.pi / 5;
    l.disc(cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.7, r * 0.55, pink, 1);
  }
  l.disc(cx, cy, r * 0.45, sunYellow, 0);
}

Layer cactusStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1: // sprout: a tiny round nub
      l.ellipse(64, 87, 5, 6, cactusGreen, 1);
      l.set(62, 84, spine, 0);
      l.set(66, 86, spine, 0);
    case 2: // grow: a short column
      cactusBody(l, 58, 70, 66);
      spines(l, 58, 70, 66);
    case 3: // bloom: taller, first arm, a bud on top
      cactusBody(l, 57, 71, 54);
      cactusArm(l, 57, 70, -1, 8, 12);
      spines(l, 57, 71, 54);
      l.ellipse(64, 52, 3, 3, pink, 1);
    case 4: // full grown: two arms and pink flowers
      cactusBody(l, 56, 72, 46);
      cactusArm(l, 56, 66, -1, 9, 14);
      cactusArm(l, 72, 74, 1, 9, 10);
      spines(l, 56, 72, 46);
      cactusFlower(l, 64, 44, 7);
      cactusFlower(l, 85, 62, 4);
  }
  return l;
}

// --- Forest Fern -----------------------------------------------------------

/// A fern frond: one chunky leaf (like your sunflower leaves) with vein
/// lines and notched edges every few pixels, so it reads as a row of
/// leaflets without turning into noise. Optional orange spore dots.
void frond(Layer l, double angleDeg, double length, double bend, double width, {bool spores = false}) {
  // Fronds start a little way up a short stalk.
  final a0 = angleDeg * math.pi / 180;
  final sx = baseX + 0.5 + math.sin(a0) * 4, sy = ground - math.cos(a0) * 4;
  l.line(baseX + 0.5, ground.toDouble(), sx, sy, fernGreen, 2, width: 2);
  final rib = blade(l, sx, sy, angleDeg, length, width, fernGreen, bend: bend);

  for (var i = 4; i < rib.length - 3; i += 4) {
    final t = i / rib.length;
    final next = rib[math.min(i + 1, rib.length - 1)];
    final dirA = math.atan2(next[1] - rib[i][1], next[0] - rib[i][0]);
    final halfW = (width * math.sin(math.pi * math.min(1, t * 1.15)) + 0.6) / 2;
    for (final side in [-1, 1]) {
      // Vein angled toward the tip, then a notch cut into the edge.
      final va = dirA + side * math.pi * 0.32;
      for (var d = 1.0; d < halfW; d += 0.5) {
        l.set((rib[i][0] + math.cos(va) * d).floor(), (rib[i][1] + math.sin(va) * d).floor(), fernGreen, 2);
      }
      final na = dirA + side * math.pi / 2;
      l.clear((rib[i][0] + math.cos(na) * (halfW + 0.2)).floor(), (rib[i][1] + math.sin(na) * (halfW + 0.2)).floor());
      if (spores && t > 0.25 && t < 0.75 && i % 8 == 0) {
        final pa = dirA + side * math.pi / 2;
        l.set((rib[i][0] + math.cos(pa) * (halfW - 1.5)).floor(), (rib[i][1] + math.sin(pa) * (halfW - 1.5)).floor(), spore, 1);
      }
    }
  }
}

/// A curled-up baby frond (fiddlehead).
void fiddlehead(Layer l, double x, double height, double curl) {
  l.line(x, ground.toDouble(), x, ground - height, fernGreen, 2, width: 2);
  final cx = x + curl * 0.6, cy = ground - height - curl * 0.6;
  l.disc(cx, cy, curl, fernGreen, 1);
  l.disc(cx + 0.5, cy + 0.5, curl * 0.45, fernGreen, 3);
}

Layer fernStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      fiddlehead(l, 64, 10, 3);
      frond(l, -30, 10, -10, 5);
    case 2:
      frond(l, -40, 20, -25, 8);
      frond(l, 40, 18, 25, 8);
      frond(l, -5, 22, -8, 8);
      fiddlehead(l, 68, 10, 3);
    case 3:
      for (final f in [[-58.0, 26.0], [-24.0, 32.0], [10.0, 32.0], [48.0, 28.0]]) {
        frond(l, f[0], f[1], f[0] * 0.6, 10);
      }
      fiddlehead(l, 60, 14, 3);
    case 4:
      for (final f in [[-66.0, 34.0], [-34.0, 40.0], [0.0, 44.0], [34.0, 40.0], [66.0, 34.0]]) {
        frond(l, f[0], f[1], f[0] * 0.65, 12, spores: f[0].abs() < 40);
      }
      fiddlehead(l, 57, 14, 3);
      fiddlehead(l, 71, 11, 3);
  }
  return l;
}

// --- Moonpetal Lily --------------------------------------------------------

void lilyBud(Layer l, double cx, double cy, {bool small = false}) {
  final rx = small ? 3.0 : 5.0, ry = small ? 4.5 : 8.0;
  l.ellipse(cx, cy, rx, ry, lavender, 1);
  l.set(cx.floor(), (cy - ry).floor(), lavender, 0);
  // a little green cup at the bottom of the bud
  l.ellipse(cx, cy + ry - 1, rx * 0.8, 2, leafGreen, 1);
}

void lilyFlower(Layer l, double cx, double cy, double r) {
  for (var k = 0; k < 6; k++) {
    final a = -math.pi / 2 + k * math.pi / 3;
    for (var d = 0.0; d <= r; d += 0.5) {
      final w = 5.0 * (1 - math.pow(d / r, 2)) + 1.0;
      l.disc(cx + math.cos(a) * d, cy + math.sin(a) * d, w / 2 + 0.6, lavender, d > r * 0.6 ? 0 : 1);
    }
  }
  l.disc(cx, cy, r * 0.28, sunYellow, 0);
  for (var k = 0; k < 6; k++) {
    final a = -math.pi / 2 + math.pi / 6 + k * math.pi / 3;
    l.set((cx + math.cos(a) * r * 0.45).floor(), (cy + math.sin(a) * r * 0.45).floor(), sunYellow, 2);
  }
}

/// Little 4-point twinkles (no outline, so they glow).
void sparkle(Layer l, int x, int y, [Ramp ramp = glow]) {
  l.set(x, y, ramp, 0);
  for (final d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    l.set(x + d[0], y + d[1], ramp, 1);
  }
}

Layer lilyStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      blade(l, 63, 92, -25, 12, 5, leafGreen, bend: -12);
      blade(l, 65, 92, 22, 10, 5, leafGreen, bend: 12);
    case 2:
      stem(l, 63, 92, 24, lean: 1, width: 3);
      blade(l, 62, 92, -45, 22, 9, leafGreen, bend: -30);
      blade(l, 66, 92, 42, 20, 9, leafGreen, bend: 30);
      lilyBud(l, 64.5, 66, small: true);
    case 3:
      stem(l, 63, 92, 36, lean: 2, width: 3);
      blade(l, 62, 92, -50, 26, 10, leafGreen, bend: -32);
      blade(l, 66, 92, 46, 24, 10, leafGreen, bend: 32);
      blade(l, 64, 80, -25, 16, 8, leafGreen, bend: -15);
      lilyBud(l, 66, 50);
    case 4:
      stem(l, 63, 92, 40, lean: 2, width: 3);
      // side stem with a second bud
      l.line(66, 70, 80, 60, leafGreen, 2, width: 3);
      blade(l, 62, 92, -54, 30, 11, leafGreen, bend: -32);
      blade(l, 66, 92, 50, 28, 11, leafGreen, bend: 32);
      blade(l, 64, 80, -28, 18, 8, leafGreen, bend: -15);
      lilyFlower(l, 65, 42, 15);
      lilyBud(l, 82, 54);
      for (final s in [[44, 32], [88, 30], [46, 58], [94, 44]]) {
        sparkle(l, s[0], s[1]);
      }
  }
  return l;
}

// --- Phoenix Bloom (Legendary) ---------------------------------------------

/// A flickering tongue of fire rising from (cx, baseY): white-hot at the
/// bottom, orange then red toward the tip.
void flame(Layer l, double cx, double baseY, double height, double width, {double sway = 1.5}) {
  for (var i = 0; i <= height; i++) {
    final t = i / height;
    final w = width * math.pow(1 - t, 0.7) * (t < 0.2 ? 0.7 + t * 1.5 : 1.0);
    final x = cx + math.sin(t * math.pi * 1.6) * sway * t;
    l.disc(x, baseY - i, math.max(0.6, w / 2), fire, t < 0.3 ? 0 : (t < 0.65 ? 1 : 2));
  }
}

/// One wing feather: a fiery blade whose outer third burns crimson.
void feather(Layer l, double x, double y, double angle, double length, double width, double bend) {
  final rib = blade(l, x, y, angle, length, width, fire, bend: bend);
  for (var i = (rib.length * 0.65).floor(); i < rib.length; i++) {
    final t = i / (rib.length - 1);
    final w = width * math.sin(math.pi * math.min(1, t * 1.15)) + 0.6;
    l.disc(rib[i][0], rib[i][1], w / 2, crimson, 1);
  }
}

Layer phoenixStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1: // two leaves around a tiny glowing bud
      blade(l, 63, 92, -28, 12, 5, leafGreen, bend: -12);
      blade(l, 65, 92, 25, 10, 5, leafGreen, bend: 12);
      l.line(64, 92, 64, 86, leafGreen, 2, width: 2);
      l.ellipse(64.5, 84, 2.5, 3.5, fire, 1);
      l.set(64, 79, ember, 1);
    case 2: // a stem with a closed, smouldering bud
      stem(l, 63, 92, 22, lean: 1, width: 3);
      blade(l, 62, 92, -46, 20, 9, leafGreen, bend: -28);
      blade(l, 66, 92, 44, 18, 9, leafGreen, bend: 28);
      l.ellipse(64.5, 66, 4, 6, fire, 2);
      l.ellipse(64.5, 62, 2, 2.5, crimson, 1);
      l.set(62, 55, ember, 1);
      l.set(68, 52, ember, 2);
    case 3: // the bud bursts into flame, wings starting to unfold
      stem(l, 63, 92, 34, lean: 1, width: 3);
      blade(l, 62, 92, -50, 24, 10, leafGreen, bend: -30);
      blade(l, 66, 92, 48, 22, 10, leafGreen, bend: 30);
      feather(l, 63, 58, -55, 12, 6, 18);
      feather(l, 66, 58, 55, 12, 6, -18);
      flame(l, 64.5, 58, 16, 8);
      l.disc(64.5, 57, 3, fire, 0);
      for (final e in [[56, 34], [72, 30], [64, 26]]) {
        l.set(e[0], e[1], ember, 1);
      }
    case 4: // full grown: a phoenix of fire with raised wings
      stem(l, 63, 92, 40, lean: 1, width: 3);
      blade(l, 62, 92, -52, 26, 10, leafGreen, bend: -30);
      blade(l, 66, 92, 50, 24, 10, leafGreen, bend: 30);
      blade(l, 64, 76, 38, 14, 7, leafGreen, bend: 20);
      // Wings: long feathers fanning out sideways, tips curling up.
      for (var k = 0; k < 4; k++) {
        final a = 52.0 + k * 15, len = 30.0 - k * 3.5;
        feather(l, 62, 52, -a, len, 8, 30);
        feather(l, 67, 52, a, len, 8, -30);
      }
      flame(l, 57, 52, 14, 6, sway: -1.5);
      flame(l, 72, 52, 14, 6);
      flame(l, 64.5, 52, 24, 10);
      l.disc(64.5, 51, 4.5, fire, 0);
      for (final e in [[50, 22], [78, 18], [64, 14], [86, 30], [42, 32], [70, 10]]) {
        sparkle(l, e[0], e[1], ember);
      }
  }
  return l;
}

// --- Crystal Lotus (Mythic) --------------------------------------------------

/// A floating, faceted crystal (a diamond shape, lit on the left).
void crystalShard(Layer l, double cx, double cy, double h) {
  final w = h * 0.6;
  for (var y = -h; y <= h; y++) {
    final half = w * (1 - y.abs() / h);
    for (var x = -half; x <= half; x++) {
      l.set((cx + x).floor(), (cy + y).floor(), crystal, x < 0 ? (y < 0 ? 0 : 1) : (y < 0 ? 1 : 2));
    }
  }
  l.set((cx - w * 0.35).floor(), (cy - h * 0.35).floor(), crystal, 0);
}

/// A pointed lotus petal: white, blushing pink at the tip.
void lotusPetal(Layer l, double x, double y, double angle, double length, double width) {
  final rib = blade(l, x, y, angle, length, width, lotusWhite, bend: angle * 0.25);
  for (var i = (rib.length * 0.75).floor(); i < rib.length; i++) {
    final t = i / (rib.length - 1);
    final w = width * math.sin(math.pi * math.min(1, t * 1.15)) + 0.6;
    l.disc(rib[i][0], rib[i][1], w / 2, pink, 0);
  }
}

/// A flat lily pad lying on the soil.
void lilyPad(Layer l, double cx, double rx) {
  l.ellipse(cx, 89, rx, 3.5, leafGreen, 1);
  l.line(cx, 89, cx + rx * 0.7, 88, leafGreen, 2);
}

Layer lotusStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      lilyPad(l, 56, 8);
      blade(l, 66, 92, 12, 10, 4, leafGreen, bend: 8);
    case 2:
      lilyPad(l, 48, 11);
      lilyPad(l, 82, 9);
      stem(l, 63, 92, 16, width: 3);
      l.ellipse(64.5, 73, 3, 5, lotusWhite, 1);
      l.ellipse(64.5, 69, 1.5, 1.5, pink, 0);
    case 3:
      lilyPad(l, 46, 13);
      lilyPad(l, 84, 11);
      stem(l, 63, 92, 28, width: 3);
      l.ellipse(64.5, 60, 5, 8.5, lotusWhite, 1);
      l.ellipse(64.5, 53.5, 2.5, 2.5, pink, 0);
      crystalShard(l, 86, 46, 6);
      sparkle(l, 46, 44);
    case 4: // full grown: an open lotus with crystals floating round it
      lilyPad(l, 44, 14);
      lilyPad(l, 86, 13);
      stem(l, 63, 92, 34, width: 3);
      blade(l, 64, 80, -30, 12, 6, leafGreen, bend: -10);
      for (final a in [-78.0, -48.0, -18.0, 18.0, 48.0, 78.0]) {
        lotusPetal(l, 64.5, 54, a, 21, 10);
      }
      for (final a in [-34.0, 0.0, 34.0]) {
        lotusPetal(l, 64.5, 57, a, 15, 9);
      }
      l.disc(64.5, 53, 3, sunYellow, 0);
      crystalShard(l, 38, 40, 8);
      crystalShard(l, 91, 34, 7);
      crystalShard(l, 64.5, 18, 9);
      crystalShard(l, 88, 62, 4);
      for (final s in [[50, 24], [80, 20], [30, 58], [100, 50]]) {
        sparkle(l, s[0], s[1]);
      }
  }
  return l;
}

// --- Golden Glory Tree (Glory) -------------------------------------------------

void trunk(Layer l, double top, double baseWidth) {
  for (var i = 0; i <= ground - top; i++) {
    final w = baseWidth - i * (baseWidth * 0.5) / (ground - top);
    l.disc(64 + math.sin(i * 0.15) * 0.8, ground - i.toDouble(), w / 2, bark, 1);
  }
}

/// A round clump of golden leaves with a lit top-left.
void goldClump(Layer l, double cx, double cy, double r) {
  l.disc(cx, cy, r, goldLeaf, 1);
  // Shaded underside, so overlapping clumps read as separate leaf balls.
  for (var y = (cy + r * 0.35).floor(); y <= (cy + r).ceil(); y++) {
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      if (dx * dx + dy * dy <= r * r) l.set(x, y, goldLeaf, 2);
    }
  }
  l.disc(cx - r * 0.3, cy - r * 0.3, r * 0.45, goldLeaf, 0);
}

Layer gloryStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      l.line(64, 92, 64, 80, bark, 1, width: 2);
      blade(l, 64, 81, -45, 9, 5, goldLeaf, bend: -10);
      blade(l, 65, 81, 42, 9, 5, goldLeaf, bend: 10);
      sparkle(l, 64, 74, goldGlow);
    case 2:
      trunk(l, 68, 4);
      for (final c in [[56.0, 68.0, 5.0], [73.0, 66.0, 5.0], [64.0, 61.0, 8.0]]) {
        goldClump(l, c[0], c[1], c[2]);
      }
      sparkle(l, 50, 54, goldGlow);
    case 3:
      trunk(l, 58, 7);
      l.line(64, 70, 52, 58, bark, 1, width: 3);
      l.line(64, 66, 78, 56, bark, 1, width: 3);
      for (final c in [[50.0, 52.0, 8.0], [79.0, 50.0, 8.0], [64.0, 44.0, 12.0], [64.0, 33.0, 8.0]]) {
        goldClump(l, c[0], c[1], c[2]);
      }
      for (final g in [[56.0, 46.0], [72.0, 40.0]]) {
        l.disc(g[0], g[1], 1.6, crimson, 0);
      }
      sparkle(l, 40, 36, goldGlow);
      sparkle(l, 90, 30, goldGlow);
    case 4: // full grown: a golden tree wearing a crown
      trunk(l, 50, 10);
      l.line(64, 89, 51, 92, bark, 2, width: 3);
      l.line(64, 89, 77, 92, bark, 2, width: 3);
      l.line(64, 62, 46, 46, bark, 1, width: 3);
      l.line(64, 58, 83, 44, bark, 1, width: 3);
      for (final c in [
        [38.0, 52.0, 7.0], [90.0, 52.0, 7.0], [46.0, 44.0, 11.0], [82.0, 42.0, 11.0],
        [64.0, 38.0, 14.0], [54.0, 28.0, 10.0], [75.0, 27.0, 10.0], [64.0, 22.0, 9.0],
      ]) {
        goldClump(l, c[0], c[1], c[2]);
      }
      for (final g in [[50.0, 40.0], [72.0, 34.0], [85.0, 48.0], [58.0, 50.0], [64.0, 27.0], [42.0, 54.0]]) {
        l.disc(g[0], g[1], 1.7, crimson, 0);
      }
      // The crown on top.
      l.rect(55, 9, 73, 13, goldLeaf, 1);
      for (final p in [55, 64, 73]) {
        final tall = p == 64 ? 8 : 6;
        for (var dy = 0; dy <= tall; dy++) {
          final half = ((tall - dy) / tall * 3).round();
          l.rect(p - half, 9 - dy, p + half, 9 - dy, goldLeaf, dy > tall - 2 ? 0 : 1);
        }
      }
      l.disc(64.5, 11, 1.6, crimson, 0);
      l.disc(58.5, 11, 1, crimson, 0);
      l.disc(70.5, 11, 1, crimson, 0);
      for (final s in [[40, 22], [92, 18], [28, 40], [102, 36], [64, 0]]) {
        sparkle(l, s[0], s[1] + 2, goldGlow);
      }
  }
  return l;
}

// --- Colour ramps for the five highest-tier plants ---------------------------

const auroraTeal = Ramp([0xFFE6FFF7, 0xFF7FF0D0, 0xFF34B89A, 0xFF1E6E62]);
const auroraViolet = Ramp([0xFFF4E8FF, 0xFFC39BF5, 0xFF8E5CD6, 0xFF5A3596]);
const auroraGlow = Ramp([0xFFFFFFFF, 0xFFD8FFF1, 0xFFA8F5DC, 0xFF7FE8C8], shaded: false, outlined: false);
const stormPurple = Ramp([0xFFE9DDFF, 0xFFA88BF0, 0xFF6B4FC8, 0xFF3E2A85]);
const electric = Ramp([0xFFFFFFFF, 0xFFCFF7FF, 0xFF7FE8FF, 0xFF3FC8F0], shaded: false, outlined: false);
const silverLeaf = Ramp([0xFFE4F2EC, 0xFFA9CFC0, 0xFF6FA394, 0xFF3F6E66]);
const silverBark = Ramp([0xFFD8D2C8, 0xFFAFA597, 0xFF7F7466, 0xFF524A3E]);
const blood = Ramp([0xFFB02838, 0xFF7E1426, 0xFF520C1A, 0xFF2A0610]);
const thornGreen = Ramp([0xFF4E7A3A, 0xFF2F5A2A, 0xFF1C3B1C, 0xFF0E220F]);
const sakuraBark = Ramp([0xFF8A6A7A, 0xFF6A4A5A, 0xFF4A3040, 0xFF2A1828]);
const pinkSoft = Ramp([0xFFFFF0F6, 0xFFFFC2DA, 0xFFF28AB4, 0xFFB85A84]);
const peach = Ramp([0xFFFFF4E6, 0xFFFFD2A8, 0xFFF2A070, 0xFFB8663E]);
const lemon = Ramp([0xFFFFFDE6, 0xFFFFF1A0, 0xFFF2D25A, 0xFFB8962E]);
const mint = Ramp([0xFFEFFFF6, 0xFFB8F0D2, 0xFF72CDA0, 0xFF3E8E68]);
const skyBlue = Ramp([0xFFEEF8FF, 0xFFB8DEFF, 0xFF78B4F0, 0xFF4A7EC0]);

void trunkOf(Layer l, double top, double baseWidth, Ramp ramp, {double sway = 0.8}) {
  for (var i = 0; i <= ground - top; i++) {
    final w = baseWidth - i * (baseWidth * 0.5) / (ground - top);
    l.disc(64 + math.sin(i * 0.15) * sway, ground - i.toDouble(), w / 2, ramp, 1);
  }
}

/// A round clump in any colour, lit top-left and shaded underneath.
void clump(Layer l, double cx, double cy, double r, Ramp ramp) {
  l.disc(cx, cy, r, ramp, 1);
  for (var y = (cy + r * 0.35).floor(); y <= (cy + r).ceil(); y++) {
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      if (dx * dx + dy * dy <= r * r) l.set(x, y, ramp, 2);
    }
  }
  l.disc(cx - r * 0.3, cy - r * 0.3, r * 0.45, ramp, 0);
}

/// A curved stem through [pts] (a list of [x, y]), [width] pixels wide.
void path(Layer l, List<List<double>> pts, Ramp ramp, {double width = 2, int level = 2}) {
  for (var i = 0; i < pts.length - 1; i++) {
    l.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ramp, level, width: width);
  }
}

/// A lightning zigzag that glows (no outline).
void zigzag(Layer l, List<List<double>> pts) {
  for (var i = 0; i < pts.length - 1; i++) {
    l.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], electric, i.isEven ? 0 : 1);
  }
}

// --- Aurora Bell (Celestial) ------------------------------------------------

/// A hanging bell flower on a short stalk, with a glowing clapper.
void bell(Layer l, double x, double y, double r, Ramp ramp) {
  l.line(x, y - r - 3, x, y - r, leafGreen, 2);
  l.ellipse(x, y, r, r * 1.1, ramp, 1);
  l.rect((x - r - 1).floor(), (y + r * 0.8).floor(), (x + r + 1).floor(), (y + r * 0.8).floor() + 1, ramp, 2);
  l.set(x.floor(), (y + r * 0.8 + 3).floor(), auroraGlow, 0);
  l.set(x.floor(), (y + r * 0.8 + 2).floor(), auroraGlow, 1);
}

Layer auroraBellStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      blade(l, 63, 92, -28, 12, 5, leafGreen, bend: -12);
      blade(l, 65, 92, 25, 10, 5, leafGreen, bend: 12);
      l.line(64, 92, 64, 84, leafGreen, 2, width: 2);
      bell(l, 66.5, 84, 2.5, auroraTeal);
    case 2:
      stem(l, 63, 92, 24, width: 3);
      blade(l, 62, 92, -46, 20, 9, leafGreen, bend: -28);
      blade(l, 66, 92, 44, 18, 9, leafGreen, bend: 28);
      path(l, [[64, 68], [68, 63], [73, 64]], leafGreen);
      bell(l, 74, 71, 3.5, auroraTeal);
    case 3:
      stem(l, 63, 92, 34, width: 3);
      blade(l, 62, 92, -50, 24, 10, leafGreen, bend: -30);
      blade(l, 66, 92, 48, 22, 10, leafGreen, bend: 30);
      path(l, [[64, 58], [70, 52], [78, 52], [84, 57]], leafGreen);
      bell(l, 75, 60, 4.5, auroraTeal);
      bell(l, 85, 64, 3.5, auroraViolet);
      sparkle(l, 90, 44, auroraGlow);
    case 4:
      stem(l, 63, 92, 44, width: 3);
      blade(l, 62, 92, -52, 26, 10, leafGreen, bend: -30);
      blade(l, 66, 92, 50, 24, 10, leafGreen, bend: 30);
      blade(l, 64, 78, -30, 14, 7, leafGreen, bend: -20);
      path(l, [[64, 48], [72, 42], [82, 42], [90, 50]], leafGreen);
      path(l, [[64, 54], [56, 48], [47, 50], [42, 56]], leafGreen);
      bell(l, 74, 51, 5, auroraTeal);
      bell(l, 88, 58, 4.5, auroraViolet);
      bell(l, 50, 57, 4.5, auroraViolet);
      bell(l, 41, 64, 3.5, auroraTeal);
      bell(l, 65, 40, 4, auroraTeal);
      for (final s in [[34, 36], [96, 34], [58, 24], [82, 26], [100, 64]]) {
        sparkle(l, s[0], s[1], auroraGlow);
      }
  }
  return l;
}

// --- Storm Orchid (Astral) --------------------------------------------------

void orchid(Layer l, double cx, double cy, double r) {
  l.ellipse(cx, cy - r * 0.8, r * 0.45, r * 0.75, stormPurple, 1); // top petal
  l.ellipse(cx - r * 0.85, cy - r * 0.2, r * 0.7, r * 0.4, stormPurple, 1); // side petals
  l.ellipse(cx + r * 0.85, cy - r * 0.2, r * 0.7, r * 0.4, stormPurple, 1);
  l.ellipse(cx - r * 0.5, cy + r * 0.55, r * 0.4, r * 0.55, stormPurple, 1); // lower petals
  l.ellipse(cx + r * 0.5, cy + r * 0.55, r * 0.4, r * 0.55, stormPurple, 1);
  l.ellipse(cx, cy + r * 0.35, r * 0.4, r * 0.5, stormPurple, 3); // lip
  l.disc(cx, cy - r * 0.05, r * 0.2, sunYellow, 0);
}

void orchidBolts(Layer l, double cx, double cy, double r) {
  zigzag(l, [[cx - r * 1.3, cy - r * 0.3], [cx - r * 0.9, cy - r * 0.05], [cx - r * 0.7, cy - r * 0.35], [cx - r * 0.35, cy - r * 0.1]]);
  zigzag(l, [[cx + r * 1.3, cy - r * 0.3], [cx + r * 0.9, cy - r * 0.05], [cx + r * 0.7, cy - r * 0.35], [cx + r * 0.35, cy - r * 0.1]]);
  zigzag(l, [[cx, cy - r * 1.4], [cx + r * 0.15, cy - r * 1.0], [cx - r * 0.1, cy - r * 0.8], [cx + r * 0.05, cy - r * 0.45]]);
}

Layer stormOrchidStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      blade(l, 62, 92, -62, 14, 7, leafGreen, bend: -8);
      blade(l, 66, 92, 58, 13, 7, leafGreen, bend: 8);
    case 2:
      blade(l, 62, 92, -66, 22, 10, leafGreen, bend: -10);
      blade(l, 66, 92, 62, 20, 10, leafGreen, bend: 10);
      path(l, [[64, 92], [64, 76], [67, 70]], leafGreen);
      l.ellipse(68.5, 67, 3, 4.5, stormPurple, 2);
    case 3:
      blade(l, 62, 92, -70, 26, 11, leafGreen, bend: -10);
      blade(l, 66, 92, 66, 24, 11, leafGreen, bend: 10);
      path(l, [[64, 92], [64, 70], [68, 60], [74, 56]], leafGreen);
      orchid(l, 74, 56, 7);
      orchidBolts(l, 74, 56, 7);
      l.ellipse(64, 66, 2.5, 3.5, stormPurple, 2);
    case 4:
      blade(l, 62, 92, -72, 30, 12, leafGreen, bend: -10);
      blade(l, 66, 92, 68, 28, 12, leafGreen, bend: 10);
      blade(l, 64, 90, -40, 18, 8, leafGreen, bend: -14);
      path(l, [[64, 92], [63, 66], [62, 52], [60, 44]], leafGreen);
      path(l, [[63, 70], [72, 64], [82, 62]], leafGreen);
      orchid(l, 60, 42, 10);
      orchid(l, 84, 62, 8);
      orchidBolts(l, 60, 42, 10);
      orchidBolts(l, 84, 62, 8);
      l.ellipse(46, 60, 2.5, 3.5, stormPurple, 2);
      path(l, [[62, 64], [52, 62], [47, 63]], leafGreen, width: 1);
      zigzag(l, [[92, 20], [98, 28], [94, 30], [100, 40]]);
      zigzag(l, [[30, 28], [34, 34], [31, 36], [36, 44]]);
  }
  return l;
}

// --- Starfall Willow (Divine) ------------------------------------------------

void star(Layer l, int x, int y) {
  l.set(x, y, goldLeaf, 0);
  for (final d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    l.set(x + d[0], y + d[1], goldLeaf, 1);
  }
}

/// The willow's crown with silver strands hanging from it.
void willow(Layer l, double cx, double cy, double rx, double ry, double strand, int stars) {
  // Hanging branches first (behind the crown): thin, swaying, leafy.
  final ends = <List<int>>[];
  for (var x = cx - rx + 1; x <= cx + rx - 1; x += 5) {
    final t = (x - cx) / rx;
    final top = cy + ry * 0.4;
    final len = strand * (0.5 + 0.5 * (1 - t.abs())) * (0.75 + 0.25 * math.sin(x * 1.7));
    final sway = t * 4;
    for (var i = 0; i < len; i++) {
      final px = (x + sway * math.pow(i / len, 1.5)).floor();
      final py = (top + i).floor();
      l.set(px, py, silverLeaf, 2);
      if (i % 4 == 1) l.set(px - 1, py, silverLeaf, 1); // little leaves
      if (i % 4 == 3) l.set(px + 1, py, silverLeaf, 1);
    }
    ends.add([(x + sway).floor(), (top + len).floor()]);
  }
  // A bumpy, leafy crown made of overlapping clumps.
  final n = (rx / 5).ceil() + 1;
  for (var i = 0; i < n; i++) {
    final t = n == 1 ? 0.0 : i / (n - 1) * 2 - 1;
    clump(l, cx + t * rx * 0.8, cy + ry * 0.2 - (1 - t * t) * ry * 0.5, ry * 0.9, silverLeaf);
  }
  clump(l, cx, cy - ry * 0.4, ry * 1.05, silverLeaf);
  for (var i = 0; i < stars && i < ends.length; i++) {
    final e = ends[(i * 5 + 2) % ends.length];
    star(l, e[0], e[1] + 2);
  }
}

Layer starfallWillowStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      l.line(64, 92, 64, 82, silverBark, 1, width: 2);
      blade(l, 64, 83, -40, 8, 4, silverLeaf, bend: -30);
      blade(l, 65, 83, 40, 8, 4, silverLeaf, bend: 30);
      star(l, 64, 76);
    case 2:
      trunkOf(l, 68, 4, silverBark);
      willow(l, 64, 64, 10, 5, 10, 1);
    case 3:
      trunkOf(l, 56, 7, silverBark);
      willow(l, 64, 50, 18, 8, 20, 3);
    case 4:
      trunkOf(l, 50, 10, silverBark);
      l.line(64, 90, 52, 92, silverBark, 2, width: 3);
      l.line(64, 90, 77, 92, silverBark, 2, width: 3);
      willow(l, 64, 40, 28, 12, 34, 6);
      for (final s in [[30, 18], [98, 14], [64, 12], [20, 48], [108, 44]]) {
        sparkle(l, s[0], s[1], goldGlow);
      }
  }
  return l;
}

// --- Dragonheart Rose (Primordial) --------------------------------------------

void rose(Layer l, double cx, double cy, double r) {
  for (var k = 0; k < 6; k++) {
    final a = k * math.pi / 3 + 0.3;
    l.disc(cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.55, r * 0.55, crimson, 1);
  }
  l.disc(cx, cy, r * 0.62, blood, 0);
  l.disc(cx + r * 0.1, cy - r * 0.05, r * 0.38, crimson, 2);
  // petal folds spiralling in
  for (var i = 0; i < 24; i++) {
    final a = i * 0.55;
    final d = r * 0.55 * (1 - i / 26);
    l.set((cx + math.cos(a) * d).floor(), (cy + math.sin(a) * d).floor(), blood, 3);
  }
  l.disc(cx, cy, math.max(1.2, r * 0.16), fire, 0); // ember heart
}

void thorns(Layer l, double x, double top, double bottom) {
  for (var y = top + 4; y < bottom - 2; y += 6) {
    final side = ((y ~/ 6) % 2 == 0) ? -1 : 1;
    l.set((x + side * 2).floor(), y.floor(), thornGreen, 2);
    l.set((x + side * 3).floor(), (y - 1).floor(), thornGreen, 3);
  }
}

Layer dragonRoseStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      blade(l, 63, 92, -30, 11, 5, thornGreen, bend: -12);
      blade(l, 65, 92, 28, 10, 5, thornGreen, bend: 12);
      l.line(64, 92, 64, 85, thornGreen, 2, width: 2);
      l.ellipse(64.5, 83, 2, 3, blood, 1);
    case 2:
      path(l, [[64, 92], [64, 70]], thornGreen, width: 3);
      thorns(l, 64, 70, 92);
      blade(l, 63, 86, -50, 16, 8, thornGreen, bend: -20);
      blade(l, 66, 82, 48, 15, 8, thornGreen, bend: 20);
      l.ellipse(64.5, 66, 3.5, 5, blood, 1);
      blade(l, 62, 70, -30, 5, 3, thornGreen, bend: -10);
      blade(l, 67, 70, 30, 5, 3, thornGreen, bend: 10);
    case 3:
      path(l, [[64, 92], [64, 60]], thornGreen, width: 3);
      thorns(l, 64, 60, 92);
      blade(l, 63, 88, -58, 20, 9, thornGreen, bend: -22);
      blade(l, 66, 82, 56, 19, 9, thornGreen, bend: 22);
      rose(l, 64.5, 54, 7);
    case 4:
      path(l, [[64, 92], [64, 54]], thornGreen, width: 3);
      thorns(l, 64, 54, 92);
      path(l, [[64, 74], [54, 68], [48, 62]], thornGreen);
      path(l, [[64, 70], [74, 64], [82, 58]], thornGreen);
      // wide "wing" leaves
      blade(l, 63, 86, -74, 30, 13, thornGreen, bend: -30);
      blade(l, 66, 84, 72, 28, 13, thornGreen, bend: 30);
      rose(l, 64.5, 44, 12);
      l.ellipse(47, 58, 3, 4.5, blood, 1);
      l.ellipse(83, 54, 3, 4.5, blood, 1);
      for (final s in [[48, 24], [80, 22], [64, 18], [92, 36], [36, 38]]) {
        sparkle(l, s[0], s[1], ember);
      }
  }
  return l;
}

// --- Eternal Sakura (Eternal) ---------------------------------------------------

Layer eternalSakuraStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1:
      l.line(64, 92, 64, 80, sakuraBark, 1, width: 2);
      l.line(64, 84, 70, 79, sakuraBark, 1);
      clump(l, 63, 78, 3, pinkSoft);
      clump(l, 71, 77, 2.5, pinkSoft);
    case 2:
      trunkOf(l, 70, 4, sakuraBark, sway: 1.5);
      for (final c in [[56.0, 66.0, 5.0], [72.0, 64.0, 5.0], [64.0, 60.0, 7.0]]) {
        clump(l, c[0], c[1], c[2], pinkSoft);
      }
    case 3:
      trunkOf(l, 58, 7, sakuraBark, sway: 2);
      path(l, [[64, 70], [52, 60]], sakuraBark, width: 3, level: 1);
      path(l, [[64, 66], [78, 56]], sakuraBark, width: 3, level: 1);
      for (final c in [
        [50.0, 54.0, 8.0, pinkSoft], [79.0, 52.0, 8.0, lavender], [64.0, 44.0, 11.0, pinkSoft], [64.0, 33.0, 7.0, peach],
      ]) {
        clump(l, c[0] as double, c[1] as double, c[2] as double, c[3] as Ramp);
      }
    case 4:
      trunkOf(l, 52, 11, sakuraBark, sway: 2.5);
      l.line(64, 89, 50, 92, sakuraBark, 2, width: 3);
      l.line(64, 89, 78, 92, sakuraBark, 2, width: 3);
      path(l, [[64, 66], [48, 52]], sakuraBark, width: 3, level: 1);
      path(l, [[64, 62], [82, 48]], sakuraBark, width: 3, level: 1);
      // a rainbow crown of blossoms, in arc order
      final ramps = [pinkSoft, peach, lemon, mint, skyBlue, lavender];
      for (var i = 0; i < 6; i++) {
        final a = math.pi + math.pi * (i + 0.5) / 6;
        clump(l, 64 + math.cos(a) * 26, 46 + math.sin(a) * 20, 10, ramps[i]);
      }
      clump(l, 64, 40, 12, pinkSoft);
      clump(l, 50, 50, 8, peach);
      clump(l, 78, 50, 8, lavender);
      // a golden halo floating above the crown
      for (var i = 0; i < 40; i++) {
        final a = i * 2 * math.pi / 40;
        l.set((64 + math.cos(a) * 12).floor(), (12 + math.sin(a) * 3).floor(), goldGlow, i.isEven ? 1 : 2);
      }
      for (final s in [[24, 30], [104, 28], [30, 60], [100, 62], [64, 4]]) {
        sparkle(l, s[0], s[1], goldGlow);
      }
  }
  return l;
}

// --- Owlbloom (Secret) ---------------------------------------------------------

const owlBrown = Ramp([0xFFE3C29A, 0xFFB98A5A, 0xFF8A5E36, 0xFF5A3A20]);
const owlCream = Ramp([0xFFFFF8EA, 0xFFF3E3C3, 0xFFD9C49E, 0xFFB09A74]);
const ink = Ramp([0xFF6A5A4A, 0xFF4A3A2A, 0xFF2A1E14, 0xFF140E08]);

/// kuwago's face as a flower: feather petals, ear tufts, big golden eyes.
void owlFace(Layer l, double cx, double cy, double r, {bool sleepy = false}) {
  for (var k = 0; k < 9; k++) {
    final a = -math.pi / 2 + k * 2 * math.pi / 9;
    l.ellipse(cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.72, r * 0.36, r * 0.32, owlBrown, 1);
  }
  blade(l, cx - r * 0.45, cy - r * 0.55, -28, r * 0.6, r * 0.28, owlBrown, bend: -6); // ear tufts
  blade(l, cx + r * 0.45, cy - r * 0.55, 28, r * 0.6, r * 0.28, owlBrown, bend: 6);
  l.disc(cx, cy, r * 0.74, owlCream, 1);
  for (final side in [-1, 1]) {
    final ex = cx + side * r * 0.36, ey = cy - r * 0.08;
    if (sleepy) {
      l.line(ex - r * 0.18, ey, ex + r * 0.18, ey + r * 0.05, ink, 2);
      continue;
    }
    l.disc(ex, ey, r * 0.33, owlCream, 0);
    l.disc(ex, ey, r * 0.26, sunYellow, 0);
    l.disc(ex, ey, math.max(1.0, r * 0.14), ink, 3);
    l.set((ex - r * 0.08).floor(), (ey - r * 0.1).floor(), owlCream, 0); // shine
  }
  l.rect((cx - 1).floor(), (cy + r * 0.2).floor(), (cx + 1).floor(), (cy + r * 0.2).floor(), fire, 1); // beak
  l.set(cx.floor(), (cy + r * 0.2 + 1).floor(), fire, 2);
}

Layer owlbloomStage(int stage) {
  final l = Layer();
  switch (stage) {
    case 1: // a little speckled egg of a bud
      blade(l, 63, 92, -30, 11, 5, leafGreen, bend: -12);
      blade(l, 65, 92, 28, 10, 5, leafGreen, bend: 12);
      l.ellipse(64.5, 85, 3, 4, owlCream, 1);
      l.set(63, 84, owlBrown, 2);
      l.set(66, 86, owlBrown, 2);
    case 2: // a sleepy owl bud
      stem(l, 63, 92, 22, width: 3);
      blade(l, 62, 92, -48, 20, 9, leafGreen, bend: -28);
      blade(l, 66, 92, 46, 18, 9, leafGreen, bend: 28);
      owlFace(l, 64.5, 64, 6, sleepy: true);
    case 3:
      stem(l, 63, 92, 32, width: 3);
      blade(l, 62, 92, -52, 24, 10, leafGreen, bend: -30);
      blade(l, 66, 92, 50, 22, 10, leafGreen, bend: 30);
      owlFace(l, 64.5, 54, 9);
    case 4: // full bloom: kuwago's face under the moon, leaves spread like wings
      stem(l, 63, 92, 40, width: 3);
      blade(l, 62, 88, -70, 30, 13, leafGreen, bend: -34);
      blade(l, 66, 88, 68, 28, 13, leafGreen, bend: 34);
      blade(l, 64, 78, -34, 14, 7, leafGreen, bend: -18);
      owlFace(l, 64.5, 44, 14);
      for (final s in [[30, 22], [98, 18], [22, 50], [106, 48], [64, 12]]) {
        sparkle(l, s[0], s[1], goldGlow);
      }
  }
  return l;
}

// ---------------------------------------------------------------------------
// Compositing: soil + plant + outline
// ---------------------------------------------------------------------------

Uint32List renderStage(Layer plant, Uint32List soil) {
  plant.shadeEdges();
  final out = Uint32List.fromList(soil);
  for (var i = 0; i < size * size; i++) {
    final ramp = plant.ramps[i];
    if (ramp != null && ramp.outlined) out[i] = ramp.colors[plant.levels[i]];
  }
  // 1-px black outline around the plant (above the soil only).
  for (var y = 0; y <= ground; y++) {
    for (var x = 0; x < size; x++) {
      if (plant.filled(x, y)) continue;
      final touches = [[1, 0], [-1, 0], [0, 1], [0, -1]].any((d) {
        final nx = x + d[0], ny = y + d[1];
        return plant.filled(nx, ny) && plant.ramps[ny * size + nx]!.outlined;
      });
      if (touches) out[y * size + x] = outlineColor;
    }
  }
  // Glow pixels go on last, un-outlined.
  for (var i = 0; i < size * size; i++) {
    final ramp = plant.ramps[i];
    if (ramp != null && !ramp.outlined) out[i] = ramp.colors[plant.levels[i]];
  }
  return out;
}

/// The soil mound from your sunflower's seed.png (rows 92 and below),
/// with the seed itself removed and the top row turned into outline.
Uint32List soilFrom(Uint32List seed) {
  final soil = Uint32List(size * size);
  for (var y = ground; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final c = seed[y * size + x];
      if ((c >> 24) == 0) continue;
      soil[y * size + x] = y == ground ? outlineColor : c;
    }
  }
  return soil;
}

/// Growth animation between two stages: the new stage "grows up" out of
/// the old one, revealed from the soil upward over 10 frames.
List<Uint32List> transition(Uint32List from, Uint32List to) {
  var top = ground;
  for (var i = 0; i < size * size; i++) {
    if ((to[i] >> 24) != 0) {
      top = math.min(top, i ~/ size);
      break;
    }
  }
  return List.generate(10, (f) {
    if (f == 0) return Uint32List.fromList(from);
    if (f == 9) return Uint32List.fromList(to);
    final cut = ground - ((ground - top) * f / 9).round();
    final frame = Uint32List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = y * size + x;
        frame[i] = y >= cut ? to[i] : from[i];
      }
    }
    return frame;
  });
}

// ---------------------------------------------------------------------------
// Wilted versions (made from ANY plant's stage PNGs — including your
// hand-drawn sunflower)
// ---------------------------------------------------------------------------

// Dry colour ramps, light → dark.
const _dryGreen = [0xFFB8A95E, 0xFF8E7C3C, 0xFF6B5627, 0xFF45361A];
const _dryYellow = [0xFFC9A64A, 0xFFA07E2E, 0xFF7A5A20, 0xFF4E3A14];
const _dryPetal = [0xFFCDB3AA, 0xFFA2827C, 0xFF7C5E5A, 0xFF4E3A38];

/// Makes a wilted copy of a stage:
///   1. the plant slumps, its outer leaves droop, and the top leans over
///   2. greens dry out to olive-brown, yellows go dull, pink/lavender fade
///   3. glowing sparkles go out
/// The soil below row 92 is left exactly as it was.
Uint32List wilt(Uint32List source, {bool dryFire = false}) {
  var top = ground;
  for (var i = 0; i < size * size; i++) {
    if ((source[i] >> 24) != 0) {
      top = math.min(top, i ~/ size);
      break;
    }
  }
  final plantHeight = math.max(1, ground - top);

  final out = Uint32List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (y > ground) {
        out[y * size + x] = source[y * size + x];
        continue;
      }
      // Work backwards: which source pixel lands here after drooping?
      final h = (ground - y) / plantHeight; // 0 at soil … 1 at the top
      final lean = 5 * h * h; // top tips to the right
      final spread = ((x - baseX).abs() / 30.0).clamp(0.0, 1.6);
      final droop = 6 * math.pow(spread, 1.5) * math.min(1, (ground - y) / 18); // outer leaves sag
      final slump = 4 * h; // whole plant sinks a little
      final sx = (x - lean).round();
      final sy = (y - droop - slump).round();
      if (sx < 0 || sx >= size || sy < 0 || sy > ground) continue;
      out[y * size + x] = _dryColor(source[sy * size + sx], dryFire: dryFire);
    }
  }
  return out;
}

int _dryColor(int argb, {bool dryFire = false}) {
  final a = argb >> 24 & 0xFF;
  if (a == 0) return 0;
  final r = (argb >> 16 & 0xFF) / 255, g = (argb >> 8 & 0xFF) / 255, b = (argb & 0xFF) / 255;
  final maxC = math.max(r, math.max(g, b)), minC = math.min(r, math.min(g, b));
  final v = maxC, s = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
  if (v < 0.12 || s < 0.15) return argb; // outlines, spines, pale bits stay

  double hue;
  final d = maxC - minC;
  if (maxC == r) {
    hue = 60 * (((g - b) / d) % 6);
  } else if (maxC == g) {
    hue = 60 * ((b - r) / d + 2);
  } else {
    hue = 60 * ((r - g) / d + 4);
  }
  if (hue < 0) hue += 360;

  int pick(List<int> ramp) => ramp[v > 0.7 ? 0 : (v > 0.5 ? 1 : (v > 0.3 ? 2 : 3))];

  if (hue >= 180 && hue < 205) return 0; // glow sparkles fade away
  if (hue >= 70 && hue < 180) return pick(_dryGreen); // leaves, stems, cactus
  if (hue >= 45 && hue < 70) return pick(_dryYellow); // sunflower petals, flower centres
  if (hue >= 240 || hue < 15) return pick(_dryPetal); // pink / lavender petals
  if (dryFire && s > 0.45 && hue < 45) return pick(_dryYellow); // flames and gold burn out (new plants only)
  return argb; // browns: seed, soil, spores
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const stageNames = ['seed', 'sprout', 'grow', 'bloom', 'fullgrown'];

/// Writes <root>/wilted/<stage>.png for every stage in <root>/stages/.
void writeWilted(String root, {bool dryFire = false}) {
  Directory('$root/wilted').createSync(recursive: true);
  for (final name in stageNames) {
    final stage = decodePng(File('$root/stages/$name.png').readAsBytesSync());
    File('$root/wilted/$name.png').writeAsBytesSync(encodePng(wilt(stage, dryFire: dryFire)));
  }
  stdout.writeln('Wrote $root/wilted (5 stages)');
}

void main() {
  final seed = decodePng(File('assets/images/plant/stages/seed.png').readAsBytesSync());
  final soil = soilFrom(seed);

  final plants = <String, Layer Function(int)>{
    'desert_cactus': cactusStage,
    'forest_fern': fernStage,
    'moonpetal_lily': lilyStage,
    'phoenix_bloom': phoenixStage,
    'crystal_lotus': lotusStage,
    'glory_tree': gloryStage,
    'aurora_bell': auroraBellStage,
    'storm_orchid': stormOrchidStage,
    'starfall_willow': starfallWillowStage,
    'dragonheart_rose': dragonRoseStage,
    'eternal_sakura': eternalSakuraStage,
    'owlbloom': owlbloomStage,
  };

  // Legendary+ plants: their flames and gold also dry out when wilted.
  const rarePlants = {
    'phoenix_bloom', 'crystal_lotus', 'glory_tree', 'aurora_bell', 'storm_orchid', 'starfall_willow',
    'dragonheart_rose', 'eternal_sakura', 'owlbloom',
  };

  for (final entry in plants.entries) {
    final root = 'assets/images/plants/${entry.key}';
    Directory('$root/stages').createSync(recursive: true);
    Directory('$root/frames').createSync(recursive: true);

    // Every plant starts from the same seed.
    final stages = <Uint32List>[seed];
    for (var s = 1; s <= 4; s++) {
      stages.add(renderStage(entry.value(s), soil));
    }
    for (var s = 0; s < 5; s++) {
      File('$root/stages/${stageNames[s]}.png').writeAsBytesSync(encodePng(stages[s]));
    }
    for (var s = 0; s < 4; s++) {
      final frames = transition(stages[s], stages[s + 1]);
      for (var f = 0; f < 10; f++) {
        File('$root/frames/${stageNames[s]}_${stageNames[s + 1]}_0$f.png').writeAsBytesSync(encodePng(frames[f]));
      }
    }
    stdout.writeln('Wrote $root (5 stages, 40 frames)');
    writeWilted(root, dryFire: rarePlants.contains(entry.key));
  }

  // Your hand-drawn sunflower gets a wilted set too (its own art is
  // never changed — only the wilted/ folder is written).
  writeWilted('assets/images/plant');
}

// ---------------------------------------------------------------------------
// Minimal PNG reader/writer (RGBA, 8-bit) — no packages needed.
// ---------------------------------------------------------------------------

Uint32List decodePng(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  var pos = 8;
  var width = 0, height = 0, colorType = 0;
  List<int>? palette, alpha;
  final idat = BytesBuilder();
  while (pos + 8 <= bytes.length) {
    final len = data.getUint32(pos);
    final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
    if (type == 'IEND') break;
    final body = bytes.sublist(pos + 8, pos + 8 + len);
    if (type == 'IHDR') {
      width = data.getUint32(pos + 8);
      height = data.getUint32(pos + 12);
      colorType = bytes[pos + 17];
      if (bytes[pos + 16] != 8) throw 'Only 8-bit PNGs are supported';
    } else if (type == 'PLTE') {
      palette = body;
    } else if (type == 'tRNS') {
      alpha = body;
    } else if (type == 'IDAT') {
      idat.add(body);
    }
    pos += 12 + len;
  }
  final bpp = switch (colorType) { 6 => 4, 2 => 3, 3 => 1, _ => throw 'Unsupported PNG colour type $colorType' };
  final raw = zlib.decode(idat.toBytes());
  final stride = width * bpp;
  final pixels = Uint8List(height * stride);
  for (var y = 0; y < height; y++) {
    final filter = raw[y * (stride + 1)];
    for (var i = 0; i < stride; i++) {
      final x = raw[y * (stride + 1) + 1 + i];
      final a = i >= bpp ? pixels[y * stride + i - bpp] : 0;
      final b = y > 0 ? pixels[(y - 1) * stride + i] : 0;
      final c = (i >= bpp && y > 0) ? pixels[(y - 1) * stride + i - bpp] : 0;
      final v = switch (filter) {
        0 => x,
        1 => x + a,
        2 => x + b,
        3 => x + ((a + b) >> 1),
        _ => x + _paeth(a, b, c),
      };
      pixels[y * stride + i] = v & 0xFF;
    }
  }
  final out = Uint32List(width * height);
  for (var i = 0; i < width * height; i++) {
    int r, g, b, a;
    if (colorType == 6) {
      r = pixels[i * 4]; g = pixels[i * 4 + 1]; b = pixels[i * 4 + 2]; a = pixels[i * 4 + 3];
    } else if (colorType == 2) {
      r = pixels[i * 3]; g = pixels[i * 3 + 1]; b = pixels[i * 3 + 2]; a = 255;
    } else {
      final idx = pixels[i];
      r = palette![idx * 3]; g = palette[idx * 3 + 1]; b = palette[idx * 3 + 2];
      a = (alpha != null && idx < alpha.length) ? alpha[idx] : 255;
    }
    out[i] = (a << 24) | (r << 16) | (g << 8) | b;
  }
  return out;
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

List<int> encodePng(Uint32List argb) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
    for (var x = 0; x < size; x++) {
      final c = argb[y * size + x];
      raw.add([(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, (c >> 24) & 0xFF]);
    }
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> body) {
    final typeBytes = type.codeUnits;
    out.add(_u32(body.length));
    out.add(typeBytes);
    out.add(body);
    out.add(_u32(_crc([...typeBytes, ...body])));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, 6, 0, 0, 0]);
  chunk('IDAT', zlib.encode(raw.toBytes()));
  chunk('IEND', []);
  return out.toBytes();
}

List<int> _u32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
