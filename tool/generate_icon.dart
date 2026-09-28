// Builds the app icon + splash logo from the owl mascot pixel art
// (lib/art/owl_art.dart), scaled up by whole pixels so it stays crisp:
//   assets/icon/app_icon.png            1024x1024  light-green square + owl (older Androids)
//   assets/icon/app_icon_foreground.png 1024x1024  owl only, transparent (Android adaptive icon)
//   assets/icon/splash_logo.png          768x768   owl only, transparent (old launch splash)
//   assets/icon/splash_lockup.png       1152x1152  kuwaGO lockup (launch splash — see bottom)
//
// Run from the project root:
//   dart run tool/generate_icon.dart
// then:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Have your OWN icon? Skip this tool: save your art as the three files
// above (same sizes), then run the two commands.

import 'dart:io';
import 'dart:typed_data';
import 'package:rooted/art/owl_art.dart';
import 'package:rooted/art/wordmark_art.dart';

const iconBackground = 0xFFDCEFC8; // soft leaf green (also in pubspec.yaml)

void main() {
  final rows = owlRows();

  Uint32List canvas(int size, {required int? background, required double fill}) {
    final out = Uint32List(size * size);
    if (background != null) out.fillRange(0, out.length, background);
    // Biggest whole-number scale that fits `fill` of the canvas.
    final scale = (size * fill / owlGrid).floor();
    final offset = (size - owlGrid * scale) ~/ 2;
    for (var y = 0; y < owlGrid; y++) {
      for (var x = 0; x < owlGrid; x++) {
        final color = owlColors[rows[y][x]];
        if (color == null) continue;
        for (var dy = 0; dy < scale; dy++) {
          final row = (offset + y * scale + dy) * size;
          out.fillRange(row + offset + x * scale, row + offset + x * scale + scale, color);
        }
      }
    }
    return out;
  }

  Directory('assets/icon').createSync(recursive: true);
  // Launchers cut icons into circles/squircles, so keep the owl inside
  // the middle (adaptive icons only show the centre ~66%).
  _write('assets/icon/app_icon.png', 1024, canvas(1024, background: iconBackground, fill: 0.72));
  _write('assets/icon/app_icon_foreground.png', 1024, canvas(1024, background: null, fill: 0.56));
  _write('assets/icon/splash_logo.png', 768, canvas(768, background: null, fill: 0.62));
  _write('assets/icon/splash_lockup.png', _splashSize, _lockupSplash());
  stdout.writeln('Wrote assets/icon/app_icon.png, app_icon_foreground.png, splash_logo.png, splash_lockup.png');
}

// --- Launch splash: the kuwaGO lockup (kuwago perched on the clock O) --------
// flutter_native_splash treats the image as 4× (xxxhdpi), so 1152 px shows
// as 288 dp — exactly the Android 12 splash icon size. At 10 px per art
// pixel that's 2.5 dp per pixel on screen, the same as `lockupPixelDp` in
// the app, so the opening starts on a frame identical to this image (no
// jump). It fits inside the 768 px circle Android 12 crops the icon to.
// (Older Androids show this still; Android 12+ plays the animated version
// from tool/generate_splash_anim.dart.)

const _splashSize = 1152;

Uint32List _lockupSplash() {
  final out = Uint32List(_splashSize * _splashSize);
  final scale = (4 * lockupPixelDp).round(); // image px per art pixel
  final left = (_splashSize - lockupWidth * scale) ~/ 2;
  final top = (_splashSize - lockupHeight * scale) ~/ 2;

  void dot(int x, int y, int color) {
    final px = left + (x - lockupLeft) * scale, py = top + (y - lockupTop) * scale;
    for (var dy = 0; dy < scale; dy++) {
      final row = (py + dy) * _splashSize;
      out.fillRange(row + px, row + px + scale, color);
    }
  }

  for (final (x, y, c) in letterPixels()) {
    dot(x, y, c);
  }
  for (final (x, y, c) in clockBodyPixels()) {
    dot(x + clockLeft, y, c);
  }
  for (final (x, y) in clockHand(restHour / 12, hourHandLength)) {
    dot(x + clockLeft, y, clockHourHand);
  }
  for (final (x, y) in clockHand(restMinute / 60, minuteHandLength)) {
    dot(x + clockLeft, y, clockMinuteHand);
  }
  for (final (x, y) in clockPin) {
    dot(x + clockLeft, y, clockOutline);
  }
  final owl = owlRows(perch: false);
  for (var y = 0; y < owl.length; y++) {
    for (var x = 0; x < owl[y].length; x++) {
      final c = owlColors[owl[y][x]];
      if (c != null) dot(x + owlLeft, y + owlTop, c);
    }
  }
  return out;
}

// --- PNG writer for any size (RGBA 8-bit) ---------------------------------

void _write(String path, int size, Uint32List argb) {
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
    out.add(_u32(body.length));
    out.add(type.codeUnits);
    out.add(body);
    out.add(_u32(_crc([...type.codeUnits, ...body])));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, 6, 0, 0, 0]);
  chunk('IDAT', zlib.encode(raw.toBytes()));
  chunk('IEND', []);
  File(path).writeAsBytesSync(out.toBytes());
}

List<int> _u32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

final _table = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
