// The kuwaGO "lockup": the pixel wordmark k·u·w·a·G + the clock O, with
// kuwago perched on top of the clock. Plain Dart (no Flutter import) so the
// SAME pixels are drawn by the phone's launch splash
// (tool/generate_splash_anim.dart, tool/generate_icon.dart), the opening
// (widgets/clock_intro.dart) and the login sign (widgets/kuwago_lockup.dart).
// That's what makes splash → app → login one seamless picture.

import 'dart:math';

/// Splash background: the same leaf green as the app icon.
const int splashGreen = 0xFFDCEFC8;

/// dp per art pixel. At 1.5 the lockup is 150 dp wide and still fits
/// inside Android 12's round splash icon (and 1.5 × 2 = whole screen pixels).
const double lockupPixelDp = 1.5;

// ---- Letters (7×7 glyphs, each glyph pixel drawn 2×2 so the letters stand
// as tall as the clock O) ------------------------------------------------------

const Map<String, List<String>> glyphs = {
  'k': ['##.....', '##.....', '##..##.', '##.##..', '####...', '##.##..', '##..##.'],
  'u': ['.......', '.......', '##...##', '##...##', '##...##', '##..###', '.###.##'],
  'w': ['.......', '.......', '##...##', '##.#.##', '#######', '###.###', '##...##'],
  'a': ['.......', '.......', '.#####.', '.....##', '.######', '##...##', '.######'],
  'G': ['..####.', '.##..##', '##.....', '##..###', '##...##', '.##..##', '..#####'],
};

const int letterColor = 0xFF3E2A1B; // "kuwa": dark brown
const int gColor = 0xFF4E7A2C; // "G": deep leaf green
const int letterShadow = 0xFFB7D69A; // soft pixel drop-shadow on the green

// ---- Layout (art pixels; y can be negative — the owl sits above) ------------

const String word = 'kuwaG';
const int letterScale = 2; // art px per glyph pixel
const int letterAdvance = 16; // 7 × 2 wide + 2 px gap
const int lettersTop = 2; // 14-px-tall letters sit on the clock's baseline
const int clockLeft = 80;
const int clockGrid = 16;
const int owlLeft = 76; // centred on the clock (clock centre x = 88)
const int owlTop = -20; // its feet (row 20) rest on the clock's rim

/// Bounding box of the whole lockup, in art pixels.
const int lockupLeft = 0, lockupTop = -20, lockupWidth = 100, lockupHeight = 36;

/// Centre of the clock (the O), relative to the lockup's top-left, in art px.
const double clockCenterX = clockLeft + clockGrid / 2 - lockupLeft; // 88
const double clockCenterY = clockGrid / 2 - lockupTop; // 28

/// Every letter pixel (x, y, colour) — shadow first, then the letters.
List<(int, int, int)> letterPixels() {
  final solid = <(int, int)>{};
  final out = <(int, int, int)>[];
  for (var i = 0; i < word.length; i++) {
    final rows = glyphs[word[i]]!;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] != '#') continue;
        for (var sy = 0; sy < letterScale; sy++) {
          for (var sx = 0; sx < letterScale; sx++) {
            solid.add((i * letterAdvance + x * letterScale + sx, lettersTop + y * letterScale + sy));
          }
        }
      }
    }
  }
  for (final (x, y) in solid) {
    if (!solid.contains((x + 1, y + 1))) out.add((x + 1, y + 1, letterShadow));
  }
  for (final (x, y) in solid) {
    out.add((x, y, x >= 4 * letterAdvance ? gColor : letterColor));
  }
  return out;
}

// ---- The clock (same look as PixelClock in widgets/kuwago_logo.dart) --------

const int clockOutline = 0xFF3E2A1B;
const int clockRim = 0xFFE8B84B;
const int clockRimShade = 0xFFB8862A;
const int clockFace = 0xFFFFF4E0;
const int clockHourHand = 0xFF8B5A34;
const int clockMinuteHand = 0xFF4E7A2C;

/// The clock body without hands: outline ring, gold rim, face, tick marks.
List<(int, int, int)> clockBodyPixels() {
  const c = (clockGrid - 1) / 2;
  final out = <(int, int, int)>[];
  for (var y = 0; y < clockGrid; y++) {
    for (var x = 0; x < clockGrid; x++) {
      final d = sqrt(pow(x - c, 2) + pow(y - c, 2));
      if (d > 7.6) continue;
      if (d > 6.7) {
        out.add((x, y, clockOutline));
      } else if (d > 5.4) {
        out.add((x, y, (x + y) > 16 ? clockRimShade : clockRim));
      } else {
        out.add((x, y, clockFace));
      }
    }
  }
  for (final t in const [(7, 2), (8, 2), (13, 7), (13, 8), (7, 13), (8, 13), (2, 7), (2, 8)]) {
    out.add((t.$1, t.$2, clockOutline));
  }
  return out;
}

/// One hand as stepped pixels. [turns] 0 = pointing up, 0.25 = right.
List<(int, int)> clockHand(double turns, double length) {
  const c = (clockGrid - 1) / 2;
  final a = turns * 2 * pi - pi / 2;
  final out = <(int, int)>{};
  for (var r = 0.0; r <= length; r += 0.5) {
    out.add(((c + cos(a) * r).round(), (c + sin(a) * r).round()));
  }
  return out.toList();
}

const double minuteHandLength = 4.6;
const double hourHandLength = 3.2;
const List<(int, int)> clockPin = [(7, 7), (8, 7), (7, 8), (8, 8)];

/// The resting pose shown on the splash: 10:10.
const double restMinute = 10, restHour = 10;
