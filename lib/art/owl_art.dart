// The owl mascot as pixel art, written as text so it can be animated in
// code (blink, look around, flap) — and turned into the app icon by
// tool/generate_icon.dart. Plain Dart (no Flutter import) so both can use it.
//
// Each character is one pixel:
//   k outline   b feathers   B dark feathers   l speckles   p belly
//   w eye white e pupil      y beak/feet       Y dark gold
//   g leaf      G dark leaf  . transparent
//
// Only the LEFT half of the owl is written out; it's mirrored to make the
// right half, so the owl is always perfectly symmetrical.

const int owlGrid = 24;

const Map<String, int> owlColors = {
  'k': 0xFF2B1A10,
  'b': 0xFF8B5A34,
  'B': 0xFF5A3A22,
  'l': 0xFFB97A45,
  'p': 0xFFF6DFC0,
  'w': 0xFFFFF4E0,
  'e': 0xFF2B1A10,
  'y': 0xFFE8B84B,
  'Y': 0xFFB8862A,
  'g': 0xFF7CB350,
  'G': 0xFF3F7A2E,
};

// Left half (12 px) of rows 0–20; mirrored into 24 px.
const _leftHalf = [
  '....k.......', // 0  ear tufts
  '....kk......',
  '....kbk.....',
  '....kbbkkkkk',
  '....kbbbbbbb',
  '...kbbbbbbbb', // 5
  '...kbbkkbbbb', //    eye top (rounded corners)
  '..kbkwwwwkbb', //    eye (x 5–8, rows 7–10)
  '..kbkwwwwkbb',
  '..kbkwwwwkby', //    beak starts (x 11)
  '..kbkwwwwkby', // 10
  '..kbbbkkbbby', //    eye bottom (rounded)
  '..kBbbbppppY', //    belly + beak tip
  '.kBBbbpplppl',
  '.kBBbppplppp',
  '.kBBbpplpplp', // 15
  '.kBBbbpppppp',
  '..kBbbbpplpp',
  '..kBBbbbpppp',
  '...kBBbbbbbb',
  '....kkkkyykk', // 20 feet
];

// Full-width rows 21–23: the branch it sits on (not mirrored — the leaf
// sticks out on one side only).
const _branch = [
  'BBBBBBBByyBBBByyBBBBBBgG',
  'llllllllllllllllllllgGGg',
  'kkkkkkkkkkkkkkkkkkkk.gG.',
];

// Raised-wing feathers for the flap frame (left side; mirrored).
// Each entry: row, then pixels starting at x = 0.
const _wingUp = <int, String>{
  8: 'k',
  9: 'kb',
  10: 'kbk',
  11: 'kbbk',
  12: '.kbB',
  13: '..kB',
};

const _eyeLefts = [5, 15]; // x where each 4-px-wide eye starts

/// Builds the owl, one string per row (24 rows × 24 chars).
///   [look]    -1 = eyes left, 0 = ahead, 1 = right
///   [blink]   eyes closed
///   [wingsUp] wings raised (flap / cheer)
///   [perch]   draw its branch; false = feet only (to stand on a ledge),
///             the bottom 3 rows are then empty
List<String> owlRows({int look = 0, bool blink = false, bool wingsUp = false, bool perch = true}) {
  final rows = <List<String>>[
    for (final half in _leftHalf) [...half.split(''), ...half.split('').reversed],
    for (final row in _branch) perch ? row.split('') : List.filled(owlGrid, '.'),
  ];

  for (final x0 in _eyeLefts) {
    if (blink) {
      // Closed eye: feathered lid with a dark line across.
      for (var x = x0; x < x0 + 4; x++) {
        rows[7][x] = 'b';
        rows[8][x] = 'b';
        rows[9][x] = 'k';
        rows[10][x] = 'b';
      }
    } else {
      // 2×2 pupil in the middle of the 4×4 eye, sliding left/right.
      final px = x0 + 1 + look.clamp(-1, 1);
      for (final y in [8, 9]) {
        rows[y][px] = 'e';
        rows[y][px + 1] = 'e';
      }
    }
  }

  if (wingsUp) {
    _wingUp.forEach((y, pixels) {
      for (var i = 0; i < pixels.length; i++) {
        if (pixels[i] == '.') continue;
        rows[y][i] = pixels[i];
        rows[y][owlGrid - 1 - i] = pixels[i];
      }
    });
  }

  return [for (final row in rows) row.join()];
}
