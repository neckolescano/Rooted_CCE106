// Draws kuwaGO's own pixel-art meadow backgrounds (no outside art), in a
// cozy cottagecore style: a sky with soft clouds, rolling hills with a
// little cottage, a winding dirt path, wildflower fields, an apple tree
// and tall foreground grass.
//
// Three seasons are drawn from the same layout:
//   garden_meadow.png         spring/summer (the default scene)
//   garden_meadow_autumn.png  golden fields, orange tree, pumpkins
//   garden_meadow_winter.png  snow, a snowy evergreen, a snowman
//
// Each is drawn at 184 x 327 pixels and scaled up 4x (736 x 1308, the size
// the app's layouts were tuned for).
//
// It also draws "land" pictures: the same art with a see-through sky, so
// the app can paint each Garden Scene's own sky (sun, moon, stars, moving
// clouds) BEHIND the hills and the tree:
//   land_meadow.png, land_autumn.png, land_winter.png
//   land_sakura.png  Japanese spring: cherry tree, torii gate, Mt. Fuji
//   land_desert.png  dunes, mesas, a saguaro cactus, an adobe house, an oasis
//
// Run from the project root:
//   dart run tool/generate_meadow.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const w = 184, h = 327, scale = 4;
const horizon = 188; // where the hills meet the fields

enum Season { summer, autumn, winter, sakura, desert }

class Pal {
  const Pal({
    required this.sky,
    required this.cloud,
    required this.farHill,
    required this.nearHill,
    required this.field,
    required this.grass,
    required this.canopy,
    required this.path,
    required this.flowers,
  });
  final List<int> sky; // top → horizon
  final List<int> cloud; // light, mid, shade
  final List<int> farHill; // light, dark
  final List<int> nearHill; // light, dark
  final List<int> field; // three stripe tones, light → dark
  final List<int> grass; // blade tones, light → dark, outline
  final List<int> canopy; // light, mid, dark, outline
  final List<int> path; // light, dark
  final List<int> flowers;
}

const summer = Pal(
  sky: [0xFF6FB8EA, 0xFF84C4EE, 0xFF9DD1F2, 0xFFB8DEF5, 0xFFD4ECF7],
  cloud: [0xFFFFFFFF, 0xFFEEF6FB, 0xFFCFE2EF],
  farHill: [0xFFA7CBB2, 0xFF93BCA0],
  nearHill: [0xFF86B97C, 0xFF6FA66A],
  field: [0xFFA4D062, 0xFF94C455, 0xFF84B84A],
  grass: [0xFF8CC152, 0xFF63A23E, 0xFF3F7A2E, 0xFF1F3A17],
  canopy: [0xFF7DB85A, 0xFF5A9A43, 0xFF3D7330, 0xFF173015],
  path: [0xFFE2C495, 0xFFCDA877],
  flowers: [0xFFFFFFFF, 0xFFFFE066, 0xFFC7A6F2, 0xFFFF9AB8, 0xFFE8483F, 0xFF5B8DEF],
);

const autumn = Pal(
  sky: [0xFF78AEDA, 0xFF93BEDF, 0xFFB2CFE2, 0xFFD3DDDF, 0xFFF0E1C8],
  cloud: [0xFFFFFBF2, 0xFFF4EADB, 0xFFDCCDB8],
  farHill: [0xFFC7C394, 0xFFB5AF7E],
  nearHill: [0xFFC2A55A, 0xFFAA8C45],
  field: [0xFFE3C76A, 0xFFD6B657, 0xFFC7A248],
  grass: [0xFFD9B456, 0xFFB98C3A, 0xFF8A6428, 0xFF3E2A12],
  canopy: [0xFFF2A444, 0xFFDD7A2E, 0xFFB3521F, 0xFF4A2210],
  path: [0xFFD9B98A, 0xFFC09A68],
  flowers: [0xFFFFE066, 0xFFE8702A, 0xFFB5402A, 0xFFF2C14E],
);

const winter = Pal(
  sky: [0xFF93AFCB, 0xFFA5BED6, 0xFFB8CCE0, 0xFFCBDAE8, 0xFFDEE7F0],
  cloud: [0xFFFFFFFF, 0xFFEEF2F7, 0xFFD3DDE8],
  farHill: [0xFFDCE6EF, 0xFFC8D6E3],
  nearHill: [0xFFEFF4F8, 0xFFDAE4EE],
  field: [0xFFF7FAFC, 0xFFEBF1F6, 0xFFDDE7F0],
  grass: [0xFFE3ECF3, 0xFFB9CAD8, 0xFF7F95A8, 0xFF3A4A58],
  canopy: [0xFF4E8A5E, 0xFF3A7050, 0xFF28543C, 0xFF12291C],
  path: [0xFFE4ECF3, 0xFFD2DDE8],
  flowers: [0xFFFFFFFF],
);

const sakura = Pal(
  sky: [0xFF9FCBEF, 0xFFB5D5F2, 0xFFCADFF3, 0xFFE0E6F2, 0xFFF6E4EC],
  cloud: [0xFFFFFFFF, 0xFFFBEFF4, 0xFFEBCFDD],
  farHill: [0xFFA9C7BC, 0xFF95B9AC],
  nearHill: [0xFF8CBF7E, 0xFF74AA6C],
  field: [0xFFA8D06A, 0xFF98C45C, 0xFF88B850],
  grass: [0xFF8CC152, 0xFF63A23E, 0xFF3F7A2E, 0xFF1F3A17],
  canopy: [0xFFFFD6E4, 0xFFF7A8C4, 0xFFD97DA0, 0xFF6E2E48], // cherry blossoms
  path: [0xFFE6D8BE, 0xFFCDBB9A],
  flowers: [0xFFFFFFFF, 0xFFFFC8DA, 0xFFFF9AB8, 0xFFF58DB3, 0xFFFFE066],
);

const desert = Pal(
  sky: [0xFF7EC3E6, 0xFF9CCFE6, 0xFFBFDCE0, 0xFFE3E2C8, 0xFFF6DDA8],
  cloud: [0xFFFFFFFF, 0xFFFFF6EA, 0xFFEBDCC6],
  farHill: [0xFFE8C08E, 0xFFD9AD78], // distant dunes
  nearHill: [0xFFF0CB90, 0xFFE2B77A],
  field: [0xFFF4D6A0, 0xFFECCA8E, 0xFFE0BC80], // sand
  grass: [0xFFF2D29A, 0xFFE3BE82, 0xFFC99E62, 0xFF6E4A28], // foreground sand
  canopy: [0xFF8CC06A, 0xFF62A04C, 0xFF437A38, 0xFF1F3A1A], // cactus green
  path: [0xFFDDB27A, 0xFFC99C64],
  flowers: [0xFFFF7FA8, 0xFFFFE066, 0xFFE8702A],
);

class Canvas {
  final px = Uint32List(w * h);
  void set(int x, int y, int c) {
    if (x >= 0 && y >= 0 && x < w && y < h) px[y * w + x] = c;
  }

  int get(int x, int y) => (x >= 0 && y >= 0 && x < w && y < h) ? px[y * w + x] : 0;

  void rect(int x0, int y0, int x1, int y1, int c) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, c);
      }
    }
  }

  void disc(double cx, double cy, double r, int Function(int x, int y) color) {
    for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
      for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
        final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
        if (dx * dx + dy * dy > r * r) continue;
        final col = color(x, y);
        if (col != -1) set(x, y, col); // -1 = leave this pixel alone
      }
    }
  }
}

/// Deterministic per-pixel noise in 0..1.
double noise(int x, int y, [int salt = 0]) {
  var n = x * 374761393 + y * 668265263 + salt * 1442695041;
  n = (n ^ (n >> 13)) * 1274126177;
  return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0;
}

double farRidge(int x) => 172 + 5 * math.sin(x * 0.06) + 3 * math.sin(x * 0.17 + 1.3);
double nearRidge(int x) => 182 + 4 * math.sin(x * 0.045 + 2.2) + 2 * math.sin(x * 0.13 + 0.4);

/// The sky of a full picture: soft colour bands, fluffy clouds, a few birds.
void drawSky(Canvas c, Season s, Pal p) {
  // --- sky: five soft bands with a dithered edge between each ---------------
  const bandH = 38.0;
  for (var y = 0; y < horizon + 12; y++) {
    final t = y / bandH;
    var band = t.floor().clamp(0, p.sky.length - 1);
    final into = t - t.floor();
    for (var x = 0; x < w; x++) {
      var b = band;
      if (into > 0.8 && band < p.sky.length - 1 && (x + y) % 2 == 0) b = band + 1;
      c.set(x, y, p.sky[b]);
    }
  }

  // --- clouds ------------------------------------------------------------------
  // A fluffy cumulus: a row of round puffs, tallest in the middle, with a
  // flat base, a lit top-left and a shaded underside.
  void cloud(double cx, double baseY, double width, double height, int seed) {
    final r = math.Random(seed);
    const n = 7;
    final puffs = <List<double>>[];
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final rad = height * (0.45 + 0.55 * math.sin(math.pi * t)) * (0.85 + r.nextDouble() * 0.3);
      puffs.add([cx - width / 2 + t * width, baseY - rad * 0.55, rad]);
    }
    // a second, smaller row on top for a lumpy crown
    for (var i = 1; i < n - 1; i += 2) {
      final pf = puffs[i];
      puffs.add([pf[0] + (r.nextDouble() - 0.5) * 6, pf[1] - pf[2] * 0.55, pf[2] * 0.7]);
    }
    for (final pf in puffs) {
      c.disc(pf[0], pf[1], pf[2], (x, y) {
        if (y > baseY) return -1;
        final fromTop = (y - (pf[1] - pf[2])) / (2 * pf[2]);
        final leftness = (x - pf[0]) / pf[2];
        if (y > baseY - height * 0.22) return p.cloud[2];
        if (fromTop < 0.45 && leftness < 0.35) return p.cloud[0];
        return p.cloud[1];
      });
    }
  }

  cloud(48, 78, 78, 20, 1);
  cloud(70, 140, 96, 17, 2);
  cloud(128, 44, 40, 11, 3);
  cloud(16, 24, 34, 8, 4);
  // thin haze streaks near the horizon
  for (final st in [
    [30, 158, 60],
    [110, 166, 70]
  ]) {
    c.rect(st[0], st[1], st[0] + st[2], st[1] + 1, p.cloud[1]);
    c.rect(st[0] + 8, st[1] - 1, st[0] + st[2] - 10, st[1] - 1, p.cloud[0]);
  }

  // little birds (not in winter)
  if (s != Season.winter) {
    for (final b in [
      [58, 78],
      [66, 73],
      [74, 80]
    ]) {
      c.set(b[0] - 1, b[1] - 1, 0xFF4A5A6A);
      c.set(b[0], b[1], 0xFF4A5A6A);
      c.set(b[0] + 1, b[1] - 1, 0xFF4A5A6A);
    }
  }
}

/// [land] = leave the sky see-through (the app paints the sky itself).
Uint32List draw(Season s, {bool land = false}) {
  final p = switch (s) {
    Season.summer => summer,
    Season.autumn => autumn,
    Season.winter => winter,
    Season.sakura => sakura,
    Season.desert => desert,
  };
  final sak = s == Season.sakura, des = s == Season.desert;
  final c = Canvas();
  final rnd = math.Random(7);

  if (!land) drawSky(c, s, p);

  // --- far backdrop, behind the far hills ----------------------------------------
  if (sak) {
    // Mt. Fuji: a broad slate-blue cone with a jagged snow cap.
    const fx = 104.0, peak = 124;
    for (var y = peak; y < horizon; y++) {
      final half = 4 + (y - peak) * 1.45;
      for (var x = (fx - half).floor(); x <= (fx + half).ceil(); x++) {
        final snowLine = 13 + 3 * math.sin(x * 0.3); // a soft, wavy edge
        final left = x < fx + (y - peak) * 0.25;
        int col;
        if (y - peak < snowLine) {
          col = left ? 0xFFFFFFFF : 0xFFDCE5F2;
        } else {
          col = left ? 0xFF8FA8CC : 0xFF7890B8;
          if (y > 160 && (x + y) % 2 == 0) col = 0xFFA7B9D6; // haze near the foot
        }
        c.set(x, y, col);
      }
    }
  } else if (des) {
    // flat-topped red rock mesas
    void mesa(int x0, int x1, int top) {
      for (var y = top; y < horizon; y++) {
        final grow = (y - top) ~/ 2;
        for (var x = x0 - grow; x <= x1 + grow; x++) {
          var col = (y - top) % 6 == 4 ? 0xFFB86A42 : 0xFFC97B4C;
          if (y - top < 2) col = 0xFFE0955E; // sunlit cap
          if (x > x1 + grow - 3) col = 0xFFA85E3A; // shaded side
          c.set(x, y, col);
        }
      }
    }

    mesa(14, 44, 148);
    mesa(112, 126, 157);
  }

  // --- far hills, then near hills ----------------------------------------------
  for (var x = 0; x < w; x++) {
    final top = farRidge(x).round();
    for (var y = top; y < horizon + 14; y++) {
      c.set(x, y, (y - top < 2 && noise(x, y, 1) > 0.3) ? p.farHill[0] : p.farHill[1]);
    }
  }
  // distant round trees (or snowy pines) on the far hills
  for (final tx in sak ? [118, 131, 146] : [66, 78, 118, 131]) { // (the torii stands at 64)
    final base = farRidge(tx).round() + 2;
    if (s == Season.winter) {
      for (var i = 0; i < 7; i++) {
        c.rect(tx - (i ~/ 2), base - 7 + i, tx + (i ~/ 2), base - 7 + i, i < 2 ? 0xFFFFFFFF : 0xFF5E7F78);
      }
    } else if (des) {
      // tiny far-off cacti
      c.rect(tx, base - 6, tx, base, 0xFF6E9A5A);
      c.rect(tx - 2, base - 4, tx - 2, base - 2, 0xFF6E9A5A);
      c.set(tx - 1, base - 2, 0xFF6E9A5A);
    } else {
      final col = switch (s) { Season.autumn => 0xFFCF7A34, Season.sakura => 0xFFF4B3CB, _ => 0xFF6A9E6A };
      final dark = switch (s) { Season.autumn => 0xFFA85A28, Season.sakura => 0xFFD98AAA, _ => 0xFF578A5A };
      c.disc(tx + 0.5, base - 4.0, 3.2, (x, y) => y > base - 4 ? dark : col);
    }
  }
  for (var x = 0; x < w; x++) {
    final top = nearRidge(x).round();
    for (var y = top; y < h; y++) {
      c.set(x, y, (y - top < 2) ? p.nearHill[0] : p.nearHill[1]);
    }
  }

  // --- fields: stripes that widen toward the viewer ---------------------------
  for (var y = horizon; y < h; y++) {
    final depth = (y - horizon) / (h - horizon);
    final stripe = ((math.sqrt(y - horizon) * 2.2).floor()) % 3;
    for (var x = 0; x < w; x++) {
      final ridge = nearRidge(x);
      if (y < ridge + 5) continue;
      var tone = stripe;
      if (noise(x, y, 2) > 0.86 - depth * 0.2) tone = (tone + 1) % 3;
      c.set(x, y, p.field[tone]);
    }
  }

  // --- the house on the hill ------------------------------------------------------
  const cx = 34;
  final ground = nearRidge(cx).round() + 1;
  if (sak) {
    japaneseHouse(c, cx, ground);
    torii(c, 64, nearRidge(64).round() + 3);
  } else if (des) {
    adobeHouse(c, cx, ground);
  } else {
    cottage(c, s, cx, ground);
  }

  // --- the winding dirt path from the cottage door toward the viewer -----------
  for (var y = ground + 1; y < h - 30; y++) {
    final d = (y - ground).toDouble();
    final centre = cx - d * 0.18 + 6 * math.sin(d * 0.045) + d * d * 0.0007;
    final half = 0.8 + d * 0.085;
    for (var x = (centre - half).floor(); x <= (centre + half).ceil(); x++) {
      final edge = (x - centre).abs() > half - 1;
      c.set(x, y, edge || noise(x, y, 3) > 0.8 ? p.path[1] : p.path[0]);
    }
  }
  if (sak) stoneLantern(c, 60, 214); // in front of the path

  // --- a little pond (frozen in winter, an oasis in the desert) -----------------
  const pondX = 15.0, pondY = 217.0;
  final water = switch (s) {
    Season.autumn => 0xFF8FB6D6,
    Season.winter => 0xFFD6E8F4,
    Season.desert => 0xFF6FC7CF,
    _ => 0xFF7FBDE8,
  };
  final waterDark = switch (s) {
    Season.autumn => 0xFF6E98BC,
    Season.winter => 0xFFB8D2E6,
    Season.desert => 0xFF4FA8B8,
    _ => 0xFF5E9FD0,
  };
  final shore = switch (s) {
    Season.autumn => 0xFF9A7A3A,
    Season.winter => 0xFFC8D6E3,
    Season.desert => 0xFF8FA85A,
    _ => 0xFF6E9A4A,
  };
  for (var y = (pondY - 5).floor(); y <= (pondY + 5).ceil(); y++) {
    for (var x = (pondX - 14).floor(); x <= (pondX + 14).ceil(); x++) {
      final dx = (x + 0.5 - pondX) / 14, dy = (y + 0.5 - pondY) / 5;
      final d = dx * dx + dy * dy;
      if (d > 1) continue;
      c.set(x, y, d > 0.75 ? shore : (dy > 0.2 ? waterDark : water));
    }
  }
  c.rect(8, 215, 13, 215, 0xFFFFFFFF); // sparkle on the water
  c.rect(18, 219, 21, 219, s == Season.winter ? 0xFFFFFFFF : 0xFFBFE3F8);
  if (s == Season.summer || sak) {
    for (final lp in [
      [6, 218],
      [22, 216],
      [14, 220]
    ]) {
      c.rect(lp[0], lp[1], lp[0] + 2, lp[1], 0xFF4E8A3A);
      c.set(lp[0] + 1, lp[1] - 1, 0xFF6FAA4E);
    }
    c.set(23, 215, 0xFFFF9AB8); // a water-lily flower
  }
  if (sak) {
    // koi
    c.rect(9, 217, 10, 217, 0xFFFF8A3A);
    c.set(11, 217, 0xFFFFFFFF);
    c.rect(18, 216, 19, 216, 0xFFFFFFFF);
    c.set(20, 216, 0xFFE8483F);
  }
  if (des) palmTree(c, 27, 214);

  // --- a wooden signpost by the path ---------------------------------------------
  c.rect(46, 199, 46, 207, 0xFF6B4A2E);
  c.rect(42, 199, 51, 201, 0xFFB08560);
  c.rect(42, 202, 51, 202, 0xFF8A6440);
  c.set(51, 200, 0xFFB08560);
  c.set(52, 200, 0xFFB08560); // arrow tip
  if (s == Season.winter) c.rect(42, 198, 51, 198, 0xFFFFFFFF);

  // --- wildflowers dotted over the fields -----------------------------------
  for (var i = 0; i < 520; i++) {
    final y = horizon + 8 + (math.pow(rnd.nextDouble(), 0.7) * (h - horizon - 60)).round();
    final x = rnd.nextInt(w);
    final col = p.flowers[rnd.nextInt(p.flowers.length)];
    if (s == Season.winter && rnd.nextDouble() > 0.15) continue; // only a few sparkles in the snow
    if (des && rnd.nextDouble() > 0.06) continue; // a rare desert bloom
    final big = y > horizon + 70;
    c.set(x, y, col);
    if (big) c.set(x + 1, y, col);
  }

  // --- apple tree on the right (a snowy evergreen in winter) -----------------
  void tree() {
    // trunk: stands at the back of the field, mostly hidden by leaves
    for (var y = 120; y < 214; y++) {
      final wob = (1.5 * math.sin(y * 0.08)).round();
      final spread = y > 204 ? (y - 204) ~/ 2 : 0; // roots flare out
      for (var x = 170 + wob - spread; x < 178 + wob + spread; x++) {
        final col = sak
            ? (x < 172 + wob - spread ? 0xFF4A3438 : (noise(x, y, 4) > 0.75 ? 0xFF86686A : 0xFF6E5256))
            : (x < 172 + wob - spread ? 0xFF4E3420 : (noise(x, y, 4) > 0.75 ? 0xFF7E5A3A : 0xFF6B4A2E));
        c.set(x, y, col);
      }
      c.set(169 + wob - spread, y, sak ? 0xFF2A1C20 : 0xFF2A1A10);
      c.set(178 + wob + spread, y, sak ? 0xFF2A1C20 : 0xFF2A1A10);
    }
    // a soft shadow under the tree
    for (var x = 156; x < w; x++) {
      c.set(x, 214, p.field[2]);
      if (x > 162) c.set(x, 215, p.field[2]);
    }
    // branch reaching left
    for (var i = 0; i < 16; i++) {
      c.rect(170 - i, 150 - (i ~/ 2), 171 - i, 151 - (i ~/ 2), sak ? 0xFF4A3438 : 0xFF5A3C24);
    }
    // canopy clumps
    final clumps = [
      [176.0, 26.0, 18.0],
      [158.0, 42.0, 15.0],
      [180.0, 60.0, 19.0],
      [150.0, 74.0, 14.0],
      [170.0, 92.0, 18.0],
      [150.0, 110.0, 13.0],
      [182.0, 118.0, 16.0],
      [162.0, 132.0, 14.0],
      [146.0, 140.0, 10.0],
      [182.0, 4.0, 14.0],
      [164.0, 12.0, 11.0],
    ];
    final mask = List<int>.filled(w * h, -1);
    for (var i = 0; i < clumps.length; i++) {
      final k = clumps[i];
      for (var y = (k[1] - k[2]).floor(); y <= (k[1] + k[2]).ceil(); y++) {
        for (var x = (k[0] - k[2]).floor(); x <= (k[0] + k[2]).ceil(); x++) {
          final dx = x + 0.5 - k[0], dy = y + 0.5 - k[1];
          // bumpy edge: leaves, not a perfect circle
          final r = k[2] * (0.88 + 0.12 * noise(x ~/ 2, y ~/ 2, 5));
          if (dx * dx + dy * dy > r * r || x < 0 || x >= w || y < 0 || y >= h) continue;
          final lit = (dx + dy) / k[2]; // -: upper-left, +: lower-right
          var tone = lit < -0.55 ? 0 : (lit < 0.35 ? 1 : 2);
          if (noise(x, y, 6) > 0.82) tone = (tone + 1).clamp(0, 2);
          mask[y * w + x] = tone;
          if (s == Season.winter && dy < -k[2] * 0.45 && noise(x, y, 7) > 0.2) mask[y * w + x] = 9; // snow cap
        }
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final m = mask[y * w + x];
        if (m < 0) {
          // outline where a leaf pixel touches empty space
          final touches = [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1]
          ].any((d) {
            final nx = x + d[0], ny = y + d[1];
            return nx >= 0 && ny >= 0 && nx < w && ny < h && mask[ny * w + nx] >= 0;
          });
          if (touches) c.set(x, y, p.canopy[3]);
          continue;
        }
        var col = m == 9 ? (noise(x, y, 8) > 0.5 ? 0xFFFFFFFF : 0xFFE3ECF4) : p.canopy[m];
        if (sak && m < 2 && noise(x, y, 14) > 0.9) col = 0xFFFFFFFF; // single open blossoms
        c.set(x, y, col);
      }
    }
    // apples (summer) or a few loose leaves (autumn)
    if (s == Season.summer) {
      for (final a in [
        [160, 52],
        [172, 70],
        [155, 84],
        [177, 96],
        [164, 112],
        [182, 40],
        [150, 66]
      ]) {
        c.set(a[0], a[1], 0xFFD8392B);
        c.set(a[0] + 1, a[1], 0xFFB82A20);
        c.set(a[0], a[1] + 1, 0xFFB82A20);
        c.set(a[0] + 1, a[1] + 1, 0xFF8E1F18);
        c.set(a[0], a[1] - 1, 0xFF3A5A20);
      }
    }
  }

  if (des) {
    saguaro(c, p);
  } else {
    tree();
  }

  // --- a row of round bushes in the middle distance ----------------------------
  final bushLight = s == Season.autumn ? 0xFFD08A3A : (s == Season.winter ? 0xFF6E9A7E : 0xFF6FA84E);
  final bushMid = s == Season.autumn ? 0xFFB06A2A : (s == Season.winter ? 0xFF4F7C62 : 0xFF558E3E);
  final bushDark = s == Season.autumn ? 0xFF7E4620 : (s == Season.winter ? 0xFF35584A : 0xFF3C6E2E);
  for (final b in [
    [6.0, 240.0, 9.0],
    [20.0, 236.0, 8.0],
    [34.0, 241.0, 7.0],
    [150.0, 238.0, 8.0],
    [164.0, 234.0, 10.0],
    [180.0, 240.0, 9.0],
    [122.0, 243.0, 6.0],
  ]) {
    if (des) {
      desertBush(c, p, b[0], b[1], b[2]);
      continue;
    }
    c.disc(b[0], b[1], b[2], (x, y) {
      if (y > b[1] + b[2] * 0.4) return -1; // flat base
      final dx = x - b[0], dy = y - b[1];
      if (s == Season.winter && dy < -b[2] * 0.5) return 0xFFFFFFFF;
      if (dx + dy < -b[2] * 0.6) return bushLight;
      return (dx + dy > b[2] * 0.3 || noise(x, y, 12) > 0.8) ? bushDark : bushMid;
    });
    if (s == Season.summer || sak) {
      for (var k = 0; k < 3; k++) {
        c.set((b[0] - b[2] * 0.5 + k * b[2] * 0.5).round(), (b[1] - b[2] * 0.2 + (k % 2) * 3).round(),
            sak ? [0xFFFF9AB8, 0xFFFFFFFF, 0xFFF58DB3][k] : [0xFFFF9AB8, 0xFFFFFFFF, 0xFFFFE066][k]);
      }
    }
  }

  // --- foreground: darker ground, tall grass blades and flowers -------------
  for (var y = 262; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = (y - 262) / (h - 262);
      final tone = noise(x, y, 9) < 0.5 - d * 0.3 ? 1 : 2;
      c.set(x, y, s == Season.winter ? p.field[tone] : p.grass[tone]);
    }
  }
  if (s == Season.winter) {
    // snow drifts over the foreground ground
    for (var x = 0; x < w; x++) {
      final top = 268 + 6 * math.sin(x * 0.08) + 3 * math.sin(x * 0.21);
      for (var y = top.round(); y < h; y++) {
        c.set(x, y, y - top < 2 ? 0xFFFFFFFF : (noise(x, y, 10) > 0.85 ? 0xFFDCE6EF : 0xFFF1F5F9));
      }
    }
  }

  if (des) {
    desertForeground(c, p);
    return c.px;
  }

  // dense grass texture: short upward strokes in three tones
  for (var y = 246; y < h + 6; y += 2) {
    for (var x = 0; x < w; x++) {
      final n = noise(x, y, 11);
      if (n > (s == Season.winter ? 0.12 : 0.55)) continue;
      final len = 2 + (n * 12).floor() + (y - 246) ~/ 14;
      final col = n < 0.12 ? p.grass[0] : (n < 0.34 ? p.grass[1] : p.grass[2]);
      for (var i = 0; i < len; i++) {
        c.set(x + (i > len * 0.6 && n < 0.3 ? 1 : 0), y - i, col);
      }
    }
  }

  // hero blades: thick, curved, outlined, framing the left and right edges
  final blades = <List<double>>[];
  for (var i = 0; i < 26; i++) {
    final left = i.isEven;
    blades.add([
      left ? rnd.nextDouble() * 62 - 6 : 124 + rnd.nextDouble() * 66,
      300 + rnd.nextDouble() * 34,
      (s == Season.winter ? 16 : 26) + rnd.nextDouble() * (s == Season.winter ? 14 : 30),
      (left ? 1 : -1) * (0.3 + rnd.nextDouble() * 0.9), // lean toward the middle
    ]);
  }
  blades.sort((a, b) => a[1].compareTo(b[1]));
  for (final bl in blades) {
    final light = rnd.nextDouble() > 0.5;
    final pts = <List<int>>[];
    for (var i = 0; i < bl[2]; i++) {
      final t = i / bl[2];
      pts.add([(bl[0] + bl[3] * 14 * t * t).round(), (bl[1] - i).round(), (t < 0.35 ? 3 : (t < 0.75 ? 2 : 1))]);
    }
    for (final pt in pts) {
      // outline first (one pixel wider on both sides)
      c.set(pt[0] - 1, pt[1], p.grass[3]);
      c.set(pt[0] + pt[2], pt[1], p.grass[3]);
    }
    final tip = pts.last;
    c.set(tip[0], tip[1] - 1, p.grass[3]);
    for (final pt in pts) {
      for (var k = 0; k < pt[2]; k++) {
        final col = k == 0 ? p.grass[0] : (light ? p.grass[1] : p.grass[2]);
        c.set(pt[0] + k, pt[1], col);
      }
    }
  }

  // flowers on stems in the foreground
  void flower(int x, int y, int petal, int centre) {
    for (var i = 0; i < 9; i++) {
      c.set(x, y + 2 + i, p.grass[2]);
    }
    c.set(x - 1, y, petal);
    c.set(x + 1, y, petal);
    c.set(x, y - 1, petal);
    c.set(x, y + 1, petal);
    c.set(x, y, centre);
    c.set(x - 1, y - 1, petal);
    c.set(x + 1, y + 1, petal);
  }

  if (s == Season.summer) {
    for (final f in [
      [18, 282, 0xFFE8483F, 0xFF3A1A10],
      [52, 300, 0xFFFFFFFF, 0xFFFFD84A],
      [96, 286, 0xFF5B8DEF, 0xFF2E4FA8],
      [134, 306, 0xFFE8483F, 0xFF3A1A10],
      [160, 290, 0xFFC7A6F2, 0xFF7A56B8],
      [74, 272, 0xFFFFFFFF, 0xFFFFD84A],
      [118, 268, 0xFFFFE066, 0xFFB88A20],
      [176, 312, 0xFFFF9AB8, 0xFFC0506E],
      [36, 310, 0xFF5B8DEF, 0xFF2E4FA8],
    ]) {
      flower(f[0], f[1], f[2], f[3]);
    }
    // lavender spikes
    for (final lx in [144, 150, 8]) {
      for (var i = 0; i < 6; i++) {
        c.set(lx, 276 + i * 2, 0xFF9A7AD8);
        c.set(lx + (i.isEven ? 1 : -1), 277 + i * 2, 0xFFB79BEA);
      }
    }
    // mushrooms, bottom left
    void mushroom(int x, int y, int r) {
      c.rect(x - 1, y, x + 1, y + r + 1, 0xFFF3E7D0);
      c.disc(x + 0.5, y + 0.0, r.toDouble(), (px, py) => py > y ? -1 : 0xFFD8392B);
      c.set(x - 1, y - r + 1, 0xFFFFFFFF);
      c.set(x + 2, y - 1, 0xFFFFFFFF);
    }

    mushroom(12, 318, 3);
    mushroom(20, 321, 2);
    // butterflies
    for (final b in [
      [60, 236, 0xFFFFB347],
      [132, 214, 0xFF8FC9FF]
    ]) {
      c.set(b[0], b[1], 0xFF3A2A1A);
      c.set(b[0] - 1, b[1] - 1, b[2]);
      c.set(b[0] + 1, b[1] - 1, b[2]);
      c.set(b[0] - 1, b[1], b[2]);
      c.set(b[0] + 1, b[1], b[2]);
    }
  } else if (sak) {
    sakuraForeground(c, p, flower);
  } else if (s == Season.autumn) {
    // pumpkins
    void pumpkin(double x, double y, double r) {
      c.disc(x, y, r, (px, py) => (px - x.floor()).abs() % 3 == 0 ? 0xFFC25A1C : 0xFFE8802A);
      c.rect(x.floor(), (y - r - 2).floor(), x.floor() + 1, (y - r).floor(), 0xFF4E7A2E);
    }

    pumpkin(16, 312, 5);
    pumpkin(28, 318, 3.5);
    pumpkin(166, 316, 4.5);
    // fallen leaves
    for (var i = 0; i < 60; i++) {
      final col = [0xFFE8702A, 0xFFB5402A, 0xFFF2C14E][rnd.nextInt(3)];
      c.set(rnd.nextInt(w), 268 + rnd.nextInt(58), col);
    }
  } else {
    // a little snowman
    c.disc(22, 306, 7, (x, y) => x > 24 && y > 307 ? 0xFFDCE6EF : 0xFFFFFFFF);
    c.disc(22, 294, 5, (x, y) => x > 24 && y > 295 ? 0xFFDCE6EF : 0xFFFFFFFF);
    c.set(20, 293, 0xFF2A2A2A);
    c.set(24, 293, 0xFF2A2A2A);
    c.rect(22, 295, 25, 295, 0xFFE8802A); // carrot nose
    c.rect(17, 299, 27, 300, 0xFFC0392B); // scarf
    c.rect(24, 300, 25, 304, 0xFFC0392B);
    c.rect(18, 287, 26, 288, 0xFF3A3A4A); // hat
    c.rect(19, 282, 25, 287, 0xFF3A3A4A);
  }
  return c.px;
}

void main() {
  void write(String name, Uint32List small, {bool alpha = false}) {
    final big = Uint32List(w * scale * h * scale);
    for (var y = 0; y < h * scale; y++) {
      for (var x = 0; x < w * scale; x++) {
        big[y * w * scale + x] = small[(y ~/ scale) * w + x ~/ scale];
      }
    }
    File('assets/images/backgrounds/$name').writeAsBytesSync(encodePng(big, w * scale, h * scale, alpha: alpha));
    stdout.writeln('Wrote assets/images/backgrounds/$name');
  }

  // full pictures (sky included)
  write('garden_meadow.png', draw(Season.summer));
  write('garden_meadow_autumn.png', draw(Season.autumn));
  write('garden_meadow_winter.png', draw(Season.winter));
  // land only (see-through sky) for the Garden Scenes and Player Cards
  write('land_meadow.png', draw(Season.summer, land: true), alpha: true);
  write('land_autumn.png', draw(Season.autumn, land: true), alpha: true);
  write('land_winter.png', draw(Season.winter, land: true), alpha: true);
  write('land_sakura.png', draw(Season.sakura, land: true), alpha: true);
  write('land_desert.png', draw(Season.desert, land: true), alpha: true);
}

/// [alpha] = keep see-through pixels (RGBA); otherwise plain RGB.
List<int> encodePng(Uint32List argb, int width, int height, {bool alpha = false}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      final c = argb[y * width + x];
      raw.add([(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF]);
      if (alpha) raw.addByte((c >> 24) & 0xFF);
    }
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> body) {
    final t = type.codeUnits;
    out
      ..add(_u32(body.length))
      ..add(t)
      ..add(body)
      ..add(_u32(_crc([...t, ...body])));
  }

  chunk('IHDR', [..._u32(width), ..._u32(height), 8, alpha ? 6 : 2, 0, 0, 0]); // 8-bit RGB(A)
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

/// The cozy cottage (summer, autumn, winter).
void cottage(Canvas c, Season s, int cx, int ground) {
  // smoke puffs drifting right
  final smoke = s == Season.winter ? 0xFFF4F7FA : 0xFFE9EEF2;
  for (final sp in [
    [42.0, ground - 22.0, 1.6],
    [45.5, ground - 27.0, 2.1],
    [50.0, ground - 32.0, 2.6]
  ]) {
    c.disc(sp[0], sp[1], sp[2], (x, y) => smoke);
  }
  c.rect(cx - 6, ground - 8, cx + 6, ground, 0xFFF3E3C3); // walls
  c.rect(cx - 6, ground - 8, cx - 6, ground, 0xFFD9C49E); // wall shade edge
  c.rect(cx + 6, ground - 8, cx + 6, ground, 0xFFD9C49E);
  c.rect(cx - 1, ground - 4, cx + 1, ground, 0xFF7A4E2E); // door
  c.rect(cx + 3, ground - 6, cx + 4, ground - 5, 0xFFFFD86B); // lit window
  c.rect(cx - 5, ground - 6, cx - 4, ground - 5, 0xFFFFD86B);
  // window boxes with tiny flowers (berries in autumn, snow in winter)
  for (final wx in [cx - 5, cx + 3]) {
    c.rect(wx - 1, ground - 4, wx + 2, ground - 4, 0xFF8A5A40);
    final bloom = switch (s) { Season.summer => 0xFFFF7FA8, Season.autumn => 0xFFE8702A, _ => 0xFFFFFFFF };
    c.set(wx - 1, ground - 5, bloom);
    c.set(wx + 2, ground - 5, bloom);
  }
  // pitched roof: widest at the eaves, narrowing to the ridge
  for (var i = 0; i < 7; i++) {
    final roofCol =
        i >= 4 && s == Season.winter ? 0xFFFFFFFF : (i == 0 ? 0xFF7A3325 : (i < 4 ? 0xFF9E4430 : 0xFFC0603F));
    c.rect(cx - 8 + i, ground - 9 - i, cx + 8 - i, ground - 9 - i, roofCol);
  }
  c.rect(cx - 8, ground - 9, cx - 8, ground - 9, 0xFF5A2418); // eave ends
  c.rect(cx + 8, ground - 9, cx + 8, ground - 9, 0xFF5A2418);
  c.rect(cx + 4, ground - 18, cx + 5, ground - 13, 0xFF8A5A40); // chimney
  if (s == Season.winter) c.rect(cx + 4, ground - 18, cx + 5, ground - 18, 0xFFFFFFFF);
  // a tiny garden fence beside it
  for (var fx = cx + 9; fx < cx + 20; fx += 3) {
    c.rect(fx, ground - 3, fx, ground, 0xFF9A7250);
  }
  c.rect(cx + 9, ground - 2, cx + 18, ground - 2, 0xFFB08560);
  if (s == Season.autumn) {
    c.disc(cx - 9.5, ground - 1.0, 1.8, (x, y) => 0xFFE8802A);
    c.set(cx - 10, ground - 3, 0xFF4E7A2E);
  }
}

// --- Cherry Blossom (Japan) pieces ---------------------------------------------

/// A little Japanese house: pale walls, dark wooden beams, glowing paper
/// windows and a tiled roof with upturned eaves.
void japaneseHouse(Canvas c, int cx, int ground) {
  const wall = 0xFFF6EEDC, beam = 0xFF5A3A28, glow = 0xFFFFE3A0;
  const tileDark = 0xFF2E3748, tile = 0xFF465269, tileLight = 0xFF5B6880;
  c.rect(cx - 7, ground - 7, cx + 7, ground, wall);
  for (final bx in [cx - 7, cx, cx + 7]) {
    c.rect(bx, ground - 7, bx, ground, beam); // posts
  }
  c.rect(cx - 7, ground - 7, cx + 7, ground - 7, beam); // top beam
  c.rect(cx - 7, ground, cx + 7, ground, 0xFF7A5A40); // veranda
  // paper (shoji) windows, lit from inside, with a thin lattice
  for (final wx in [cx - 5, cx + 2]) {
    c.rect(wx, ground - 5, wx + 3, ground - 2, glow);
    c.rect(wx + 1, ground - 5, wx + 1, ground - 2, 0xFFC9A77A);
    c.rect(wx, ground - 4, wx + 3, ground - 4, 0xFFC9A77A);
  }
  // roof: a wide lower skirt, then the main roof narrowing to the ridge
  for (var i = 0; i < 6; i++) {
    final col = i == 0 ? tileDark : (i < 3 ? tile : tileLight);
    c.rect(cx - 10 + i, ground - 8 - i, cx + 10 - i, ground - 8 - i, col);
  }
  // upturned eave tips
  c.set(cx - 11, ground - 9, tileDark);
  c.set(cx + 11, ground - 9, tileDark);
  c.rect(cx - 5, ground - 14, cx + 5, ground - 14, tileDark); // ridge
  c.set(cx - 6, ground - 15, tileDark);
  c.set(cx + 6, ground - 15, tileDark);
}

/// A red torii gate.
void torii(Canvas c, int tx, int b) {
  const red = 0xFFD8432F, redDark = 0xFFA63224, black = 0xFF2A1C1C;
  for (final px in [tx - 5, tx + 4]) {
    c.rect(px, b - 13, px, b, red);
    c.rect(px + 1, b - 13, px + 1, b, redDark);
    c.rect(px, b, px + 1, b, black); // feet
  }
  c.rect(tx - 7, b - 9, tx + 7, b - 9, red); // lower beam (nuki)
  c.rect(tx, b - 12, tx, b - 10, red); // centre strut
  c.rect(tx - 8, b - 13, tx + 8, b - 13, red); // upper beam
  c.rect(tx - 9, b - 14, tx + 9, b - 14, black); // top beam (kasagi)
  c.set(tx - 10, b - 15, black);
  c.set(tx + 10, b - 15, black);
}

/// A stone lantern (toro) with a warm light inside.
void stoneLantern(Canvas c, int lx, int b) {
  const stone = 0xFFB9B8AE, dark = 0xFF8A8982, light = 0xFFFFD86B;
  c.rect(lx - 2, b - 1, lx + 2, b, dark); // foot
  c.rect(lx - 1, b - 5, lx + 1, b - 2, stone); // post
  c.rect(lx - 2, b - 8, lx + 2, b - 6, stone); // fire box
  c.rect(lx - 1, b - 7, lx + 1, b - 7, light);
  c.rect(lx - 3, b - 9, lx + 3, b - 9, dark); // roof
  c.rect(lx - 2, b - 10, lx + 2, b - 10, dark);
  c.set(lx, b - 11, dark);
}

/// Cherry Blossom foreground: pink and white flowers, fallen petals.
void sakuraForeground(Canvas c, Pal p, void Function(int x, int y, int petal, int centre) flower) {
  for (final f in [
    [18, 282, 0xFFFF9AB8, 0xFFC0506E],
    [52, 300, 0xFFFFFFFF, 0xFFFFD84A],
    [96, 286, 0xFFFFC8DA, 0xFFE06A94],
    [134, 306, 0xFFFF9AB8, 0xFFC0506E],
    [160, 290, 0xFFFFFFFF, 0xFFF58DB3],
    [74, 272, 0xFFFFC8DA, 0xFFE06A94],
    [118, 268, 0xFFFFFFFF, 0xFFFFD84A],
    [176, 312, 0xFFFF9AB8, 0xFFC0506E],
    [36, 310, 0xFFFFC8DA, 0xFFE06A94],
  ]) {
    flower(f[0], f[1], f[2], f[3]);
  }
  // petals that have already fallen on the grass
  final r = math.Random(31);
  for (var i = 0; i < 150; i++) {
    final x = r.nextInt(w), y = horizon + 10 + r.nextInt(h - horizon - 10);
    final col = r.nextBool() ? 0xFFFFC8DA : 0xFFF58DB3;
    c.set(x, y, col);
    if (y > 250 && r.nextBool()) c.set(x + 1, y, col);
  }
  // butterflies
  for (final b in [
    [60, 236, 0xFFFFE066],
    [132, 214, 0xFFFFFFFF]
  ]) {
    c.set(b[0], b[1], 0xFF3A2A1A);
    c.set(b[0] - 1, b[1] - 1, b[2]);
    c.set(b[0] + 1, b[1] - 1, b[2]);
    c.set(b[0] - 1, b[1], b[2]);
    c.set(b[0] + 1, b[1], b[2]);
  }
}

// --- Desert pieces -------------------------------------------------------------

/// A two-storey adobe (clay) house with beam ends and a chili string.
void adobeHouse(Canvas c, int cx, int ground) {
  const clay = 0xFFD99A6A, lit = 0xFFE8B080, shade = 0xFFB97A4E, cap = 0xFFC98A5A, wood = 0xFF6B4A2E;
  void block(int x0, int x1, int top, int bottom) {
    c.rect(x0, top, x1, bottom, clay);
    c.rect(x0, top, x0, bottom, lit);
    c.rect(x1, top, x1, bottom, shade);
    c.rect(x0 - 1, top - 1, x1 + 1, top - 1, cap); // parapet
    for (var vx = x0 + 1; vx < x1; vx += 3) {
      c.set(vx, top + 1, wood); // beam ends (vigas)
    }
  }

  block(cx - 6, cx - 1, ground - 15, ground - 9); // upper storey
  block(cx - 8, cx + 7, ground - 8, ground);
  c.rect(cx - 1, ground - 4, cx + 1, ground, wood); // door
  c.rect(cx + 3, ground - 5, cx + 4, ground - 4, 0xFFFFD86B); // lit windows
  c.rect(cx - 6, ground - 5, cx - 5, ground - 4, 0xFFFFD86B);
  c.rect(cx - 4, ground - 13, cx - 3, ground - 12, 0xFFFFD86B);
  for (var y = ground - 7; y <= ground - 4; y++) {
    c.set(cx + 6, y, y.isEven ? 0xFFC0392B : 0xFFE0502F); // chili string
  }
  c.disc(cx + 10.5, ground - 1.5, 2.2, (x, y) => x > cx + 11 ? 0xFFA85E3A : 0xFFC97B4C); // clay pot
}

/// A palm tree leaning over the oasis.
void palmTree(Canvas c, int bx, int by) {
  const trunk = 0xFF8A6440, trunkDark = 0xFF6B4A2E, frond = 0xFF4E9A3A, frondDark = 0xFF357028;
  var tx = bx.toDouble();
  for (var i = 0; i < 24; i++) {
    tx = bx + i * i / 110;
    c.set(tx.round(), by - i, i.isEven ? trunk : trunkDark);
    c.set(tx.round() + 1, by - i, trunkDark);
  }
  final topX = tx.round(), topY = by - 24;
  for (final dir in [-1.2, -0.7, 0.6, 1.1, 0.1]) {
    for (var k = 0; k < 11; k++) {
      final x = (topX + dir * k).round();
      final y = (topY - 3 * math.sin(k / 10 * math.pi * 0.8) + k * 0.45 * (dir.abs() + 0.2)).round();
      c.set(x, y, frond);
      c.set(x, y + 1, frondDark);
    }
  }
  c.rect(topX, topY + 1, topX + 1, topY + 2, 0xFF5A3A20); // coconuts
}

/// A tall saguaro cactus where the meadow has its apple tree.
void saguaro(Canvas c, Pal p) {
  final mask = List<bool>.filled(w * h, false);
  void column(int x0, int x1, int y0, int y1) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (y - y0 < 2 && (x == x0 || x == x1)) continue; // rounded top
        if (x >= 0 && x < w) mask[y * w + x] = true;
      }
    }
  }

  column(160, 171, 104, 214); // trunk
  column(149, 155, 132, 163); // left arm, up
  column(149, 160, 158, 163); // left arm, elbow
  column(175, 180, 146, 177); // right arm, up
  column(171, 180, 172, 177); // right arm, elbow
  // a soft shadow under it
  for (var x = 150; x < w; x++) {
    c.set(x, 214, p.field[2]);
    if (x > 156) c.set(x, 215, p.field[2]);
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!mask[y * w + x]) {
        final touches = [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1]
        ].any((d) {
          final nx = x + d[0], ny = y + d[1];
          return nx >= 0 && ny >= 0 && nx < w && ny < h && mask[ny * w + nx];
        });
        if (touches) c.set(x, y, p.canopy[3]);
        continue;
      }
      // vertical ribs: lit on the left, darker grooves every third pixel
      var tone = x % 3 == 0 ? 2 : (x < 166 && x > 151 ? 0 : 1);
      if (x > 176 || (x > 168 && x < 172)) tone = x % 3 == 0 ? 2 : 1;
      c.set(x, y, p.canopy[tone]);
      if (x % 3 == 1 && y % 4 == 0) c.set(x, y, 0xFFE9E2B0); // tiny spines
    }
  }
  // flowers on top
  for (final f in [
    [164, 103],
    [167, 104],
    [151, 131],
    [177, 145]
  ]) {
    c.set(f[0], f[1], 0xFFFF7FA8);
    c.set(f[0] + 1, f[1], 0xFFFFD0E0);
  }
}

/// A barrel cactus or a sandstone rock in place of a round bush.
void desertBush(Canvas c, Pal p, double bx, double by, double r) {
  final rock = (bx * 7).round() % 2 == 0;
  if (rock) {
    c.disc(bx, by, r * 0.8, (x, y) {
      if (y > by + r * 0.3) return -1;
      final dx = x - bx, dy = y - by;
      if (dx + dy < -r * 0.5) return 0xFFD2B48C;
      return dx + dy > r * 0.3 ? 0xFF8A6E58 : 0xFFB0927A;
    });
  } else {
    c.disc(bx, by, r * 0.6, (x, y) {
      if (y > by + r * 0.3) return -1;
      return (x - bx.floor()) % 2 == 0 ? p.canopy[2] : p.canopy[1];
    });
    c.set(bx.round(), (by - r * 0.6).round(), 0xFFFF7FA8);
  }
}

/// Desert foreground: rippled sand, a prickly pear, rocks and a few blooms.
void desertForeground(Canvas c, Pal p) {
  // wind ripples in the sand
  for (var row = 0; row < 16; row++) {
    final y0 = 250 + row * 5;
    for (var x = 0; x < w; x++) {
      if (noise(x ~/ 3, row, 15) < 0.25) continue;
      final y = (y0 + 1.5 * math.sin(x * 0.12 + row * 1.7)).round();
      c.set(x, y, p.grass[2]);
      c.set(x, y - 1, p.grass[0]);
    }
  }
  // prickly pear pads, bottom left
  for (final pad in [
    [16.0, 304.0, 8.0],
    [8.0, 292.0, 5.5],
    [25.0, 290.0, 5.5],
    [19.0, 280.0, 4.5],
  ]) {
    c.disc(pad[0], pad[1], pad[2] + 1, (x, y) => p.canopy[3]);
    c.disc(pad[0], pad[1], pad[2], (x, y) {
      final dx = x - pad[0], dy = y - pad[1];
      if (noise(x, y, 16) > 0.9) return 0xFFE9E2B0; // spines
      return dx + dy < -pad[2] * 0.4 ? p.canopy[0] : (dx + dy > pad[2] * 0.4 ? p.canopy[2] : p.canopy[1]);
    });
  }
  for (final f in [
    [19, 275],
    [25, 285],
    [7, 287]
  ]) {
    c.rect(f[0], f[1], f[0] + 1, f[1] + 1, 0xFFE0386E); // pink fruit
  }
  // rocks, bottom right
  for (final r in [
    [164.0, 314.0, 10.0],
    [178.0, 320.0, 6.0],
    [120.0, 322.0, 4.0],
  ]) {
    c.disc(r[0], r[1], r[2], (x, y) {
      final dx = x - r[0], dy = y - r[1];
      if (dx + dy < -r[2] * 0.5) return 0xFFD2B48C;
      return dx + dy > r[2] * 0.2 ? 0xFF8A6E58 : 0xFFB0927A;
    });
  }
  // a few desert flowers
  for (final f in [
    [60, 296, 0xFFE8702A],
    [96, 284, 0xFFFFE066],
    [140, 300, 0xFFFF7FA8],
    [80, 312, 0xFFE8702A]
  ]) {
    c.rect(f[0], f[1] + 1, f[0], f[1] + 4, p.canopy[2]);
    c.set(f[0] - 1, f[1], f[2]);
    c.set(f[0] + 1, f[1], f[2]);
    c.set(f[0], f[1] - 1, f[2]);
    c.set(f[0], f[1], 0xFF6E4A28);
  }
}
