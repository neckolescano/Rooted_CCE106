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
void sparkle(Layer l, int x, int y) {
  l.set(x, y, glow, 0);
  for (final d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    l.set(x + d[0], y + d[1], glow, 1);
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
Uint32List wilt(Uint32List source) {
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
      out[y * size + x] = _dryColor(source[sy * size + sx]);
    }
  }
  return out;
}

int _dryColor(int argb) {
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
  return argb; // browns: seed, soil, spores
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const stageNames = ['seed', 'sprout', 'grow', 'bloom', 'fullgrown'];

/// Writes <root>/wilted/<stage>.png for every stage in <root>/stages/.
void writeWilted(String root) {
  Directory('$root/wilted').createSync(recursive: true);
  for (final name in stageNames) {
    final stage = decodePng(File('$root/stages/$name.png').readAsBytesSync());
    File('$root/wilted/$name.png').writeAsBytesSync(encodePng(wilt(stage)));
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
    writeWilted(root);
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
