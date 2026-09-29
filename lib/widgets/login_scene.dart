// The login page's pixel scene (see screens/login_screen.dart): a morning
// garden under a wooden pergola, the kuwaGO sign that hangs from its hook on
// two chains, and the little living details (sun, clouds, butterflies,
// drifting leaves). All drawn in code on a pixel grid, in the same style as
// the splash.

import 'dart:math';
import 'package:flutter/material.dart';
import '../art/wordmark_art.dart';
import '../theme/app_theme.dart';
import 'kuwago_lockup.dart';

Paint _px(int argb) => Paint()
  ..isAntiAlias = false
  ..color = Color(argb);

Paint _pxa(int argb, double alpha) => Paint()
  ..isAntiAlias = false
  ..color = Color(argb).withValues(alpha: alpha.clamp(0.0, 1.0));

double _snap(double v, [double s = 4]) => (v / s).round() * s;

/// Where things sit on the login scene, from the screen size and its safe
/// padding — shared by the painters and the login screen.
class LoginLayout {
  LoginLayout(Size size, EdgeInsets padding)
      : width = size.width,
        height = size.height,
        beamTop = padding.top + 16,
        chainLen = max(70.0, size.height * 0.11);

  final double width, height, beamTop, chainLen;
  static const double beamH = 20;
  static const double signW = 290, signH = 124;
  static const double owlSize = 48; // 2 dp per pixel

  /// The hook the sign hangs from (the pivot it swings around).
  Offset get hook => Offset(width / 2, beamTop + beamH + 8);

  /// Where kuwago hovers to knock the hook (centre of the owl).
  Offset get hookPerch => hook + const Offset(-26, -6);

  /// kuwago's seat on the sign's top edge, relative to the hook.
  Offset get perch => Offset(78, chainLen);

  double get meadowTop => _snap(height * 0.62);
}

/// The wooden sign: three planks, nails, an ivy sprig, carved kuwaGO.
class HangingSign extends StatelessWidget {
  const HangingSign({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppInfo.name,
      excludeSemantics: true,
      child: CustomPaint(
        painter: const _BoardPainter(),
        foregroundPainter: const _SprigPainter(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            const RepaintBoundary(
              child: SizedBox(width: 96 * 2.5, height: 16 * 2.5, child: CustomPaint(painter: _SignWordPainter())),
            ),
            const SizedBox(height: 8),
            Text(
              '★ ${AppInfo.tagline.toUpperCase()} ★',
              style: AppTheme.body(size: 12, color: const Color(0xFFF6DFC0), weight: FontWeight.w900)
                  .copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Letters + clock of the lockup, cream-carved on wood.
class _SignWordPainter extends CustomPainter {
  const _SignWordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const s = 2.5;
    for (final (x, y, color) in letterPixels()) {
      final c = color == letterShadow ? 0xFF4A2E1A : (color == gColor ? 0xFF9BD06A : 0xFFF6DFC0);
      canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), _px(c));
    }
    canvas.save();
    canvas.translate(clockLeft * s, 0);
    const LockupClockPainter(minute: restMinute, hour: restHour).paint(canvas, const Size(16 * s, 16 * s));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SignWordPainter old) => false;
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const p = 3.0;
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(p * 2, h, w - p * 2, p * 2), _pxa(0xFF2B1A10, 0.25)); // soft shadow
    canvas.drawRect(Rect.fromLTWH(p, 0, w - 2 * p, h), _px(0xFF2B1A10));
    canvas.drawRect(Rect.fromLTWH(0, p, w, h - 2 * p), _px(0xFF2B1A10));
    final plankH = (h - 2 * p) / 3;
    const tones = [0xFF9A6438, 0xFF8B5A34, 0xFF96603A];
    for (var i = 0; i < 3; i++) {
      final top = p + i * plankH;
      canvas.drawRect(Rect.fromLTWH(p, top, w - 2 * p, plankH - 1), _px(tones[i]));
      canvas.drawRect(Rect.fromLTWH(p, top, w - 2 * p, p), _px(0xFFB97A45));
      final r = Random(i + 3);
      for (var g = 0; g < 7; g++) {
        final gx = p * 2 + r.nextDouble() * (w - 40);
        canvas.drawRect(
            Rect.fromLTWH(_snap(gx, p), top + plankH / 2 + (r.nextInt(3) - 1) * p, 18 + r.nextDouble() * 20, p),
            _px(0xFF7A4C2B));
      }
      canvas.drawRect(Rect.fromLTWH(p, top + plankH - 1 - p, w - 2 * p, p), _px(0xFF6B4226));
    }
    for (final x in [p * 3, w - p * 5]) {
      for (final y in [p * 2, h - p * 4]) {
        canvas.drawRect(Rect.fromLTWH(x, y, p * 2, p * 2), _px(0xFF3E2A1B));
        canvas.drawRect(Rect.fromLTWH(x, y, p, p), _px(0xFFB8A48A));
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => false;
}

/// A little ivy sprig growing over the sign's lower-left corner.
class _SprigPainter extends CustomPainter {
  const _SprigPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const leaves = [(6.0, 0.62), (16.0, 0.72), (8.0, 0.82), (26.0, 0.9), (38.0, 0.97), (-2.0, 0.74)];
    for (var i = 0; i < leaves.length; i++) {
      final (x, fy) = leaves[i];
      final y = _snap(size.height * fy, 3);
      canvas.drawRect(Rect.fromLTWH(x, y, 9, 6), _px(i.isEven ? 0xFF5E9A3A : 0xFF7CB350));
      canvas.drawRect(Rect.fromLTWH(x + 3, y + 6, 3, 3), _px(0xFF4E7A2C));
    }
    canvas.drawRect(Rect.fromLTWH(20, _snap(size.height * 0.84, 3), 6, 6), _px(0xFFF07AA6));
    canvas.drawRect(Rect.fromLTWH(22, _snap(size.height * 0.84, 3) + 2, 2, 2), _px(0xFFF2C230));
  }

  @override
  bool shouldRepaint(_SprigPainter old) => false;
}

/// Two chains in a V, from the hook down to the sign's top corners.
class SignChainsPainter extends CustomPainter {
  const SignChainsPainter({required this.chainLen, required this.spread});

  final double chainLen, spread;

  @override
  void paint(Canvas canvas, Size size) {
    final top = Offset(size.width / 2, 0);
    for (final dir in [-1.0, 1.0]) {
      final end = Offset(size.width / 2 + dir * spread, chainLen + 4);
      final n = ((end - top).distance / 7).floor();
      for (var i = 0; i <= n; i++) {
        final pt = Offset.lerp(top, end, i / n)!;
        final wide = i.isEven;
        final r = Rect.fromCenter(
            center: Offset(pt.dx.roundToDouble(), pt.dy.roundToDouble()), width: wide ? 6 : 3, height: wide ? 5 : 6);
        canvas.drawRect(r, _px(0xFF4A4038));
        canvas.drawRect(Rect.fromLTWH(r.left + 1, r.top + 1, 2, 2), _px(0xFF8E857B));
      }
    }
  }

  @override
  bool shouldRepaint(SignChainsPainter old) => old.chainLen != chainLen;
}

/// Warm morning sky fading into leaf green, with the splash's leaf pattern.
class LoginSkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.35, 0.6],
          colors: [Color(0xFFFCEBC4), Color(0xFFEAF5D8), Color(splashGreen)],
        ).createShader(Offset.zero & size),
    );
    final r = Random(5);
    const shape = ['.##', '###', '##.', '#..'];
    for (var row = 0; row < 26; row++) {
      for (var col = 0; col < 10; col++) {
        final x = col * 44.0 + (row.isOdd ? 22 : 0) + r.nextDouble() * 10, y = row * 40.0 + r.nextDouble() * 10;
        final flip = r.nextBool();
        final paint = _pxa(0xFFB9D99A, 0.35 + 0.25 * (y / h));
        if (y > h * 0.52 || y < h * 0.12) continue;
        for (var sy = 0; sy < 4; sy++) {
          for (var sx = 0; sx < 3; sx++) {
            if (shape[sy][flip ? 2 - sx : sx] != '#') continue;
            canvas.drawRect(Rect.fromLTWH(_snap(x, 2.5) + sx * 2.5, _snap(y, 2.5) + sy * 2.5, 2.5, 2.5), paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(LoginSkyPainter old) => false;
}

/// A pixel sun rising over the hills with slowly turning rays, and
/// drifting clouds.
class LoginSunCloudsPainter extends CustomPainter {
  LoginSunCloudsPainter({required this.sec});

  final double sec;

  static const _cloud = ['...####.....', '.#########..', '############', '.oooooooooo.'];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sun = Offset(_snap(w * 0.2), _snap(h * 0.47));
    final rayPaint = _pxa(0xFFFFD66B, 0.55);
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5 + sec * 0.15;
      for (var r = 30.0; r < 44; r += 4) {
        final p = sun + Offset(cos(a), sin(a)) * r;
        canvas.drawRect(Rect.fromLTWH(_snap(p.dx), _snap(p.dy), 4, 4), rayPaint);
      }
    }
    for (var y = -6; y < 6; y++) {
      for (var x = -6; x < 6; x++) {
        final d = sqrt(pow(x + 0.5, 2) + pow(y + 0.5, 2));
        if (d > 6) continue;
        canvas.drawRect(Rect.fromLTWH(sun.dx + x * 4, sun.dy + y * 4, 4, 4), _px(d > 4.8 ? 0xFFF2B94B : 0xFFFFE08A));
      }
    }
    const clouds = [(y: 0.19, speed: 0.012, off: 0.3), (y: 0.27, speed: 0.008, off: 0.75), (y: 0.36, speed: 0.006, off: 0.05)];
    const px = 4.0;
    final cw = _cloud[0].length * px;
    for (final cl in clouds) {
      final x = _snap(((cl.off + sec * cl.speed) % 1.0) * (w + cw) - cw);
      final y = _snap(h * cl.y);
      for (var r = 0; r < _cloud.length; r++) {
        for (var col = 0; col < _cloud[r].length; col++) {
          final ch = _cloud[r][col];
          if (ch == '.') continue;
          canvas.drawRect(Rect.fromLTWH(x + col * px, y + r * px, px, px), _px(ch == 'o' ? 0xFFE6EFE0 : 0xFFFFFFFF));
        }
      }
    }
  }

  @override
  bool shouldRepaint(LoginSunCloudsPainter old) => old.sec != sec;
}

/// Hills with a row of round trees, the meadow, flowers and a picket fence.
class LoginLandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double farTop(double x) => _snap(h * 0.52 + 12 * sin(x / 80) + 6 * sin(x / 33 + 1));
    for (var x = 0.0; x < w; x += 4) {
      canvas.drawRect(Rect.fromLTWH(x, farTop(x), 4, h), _px(0xFFC3E0A4));
    }
    final tr = Random(21);
    for (var x = 8.0; x < w; x += 22 + tr.nextDouble() * 18) {
      final r = 7 + tr.nextInt(5);
      final base = farTop(x) + 4;
      final dark = tr.nextBool();
      for (var y = -r; y <= r; y++) {
        final half = sqrt(max(0, r * r - y * y)).roundToDouble();
        canvas.drawRect(Rect.fromLTWH(_snap(x - half, 2), base - r + y, half * 2, 1.5), _px(dark ? 0xFF9CCB7A : 0xFFA9D386));
      }
      canvas.drawRect(Rect.fromLTWH(_snap(x, 2) - 1, base, 3, 6), _px(0xFF8B6A4E));
    }
    for (var x = 0.0; x < w; x += 4) {
      final t2 = _snap(h * 0.57 + 9 * sin(x / 60 + 2));
      canvas.drawRect(Rect.fromLTWH(x, t2, 4, h - t2), _px(0xFFAED58A));
    }
    final meadowTop = _snap(h * 0.62);
    canvas.drawRect(Rect.fromLTWH(0, meadowTop, w, h - meadowTop), _px(0xFF93C46D));
    canvas.drawRect(Rect.fromLTWH(0, meadowTop, w, 4), _px(0xFFA8D27F));
    final m = Random(9);
    for (var i = 0; i < 80; i++) {
      canvas.drawRect(
          Rect.fromLTWH(_snap(m.nextDouble() * w), meadowTop + 8 + _snap(m.nextDouble() * (h - meadowTop - 8)), 4, 4),
          _px(0xFF82B75E));
    }
    for (var i = 0; i < 26; i++) {
      final x = _snap(m.nextDouble() * w), y = meadowTop + 16 + _snap(m.nextDouble() * (h - meadowTop - 30));
      canvas.drawRect(Rect.fromLTWH(x, y - 6, 2, 6), _px(0xFF6FA84B));
      canvas.drawRect(Rect.fromLTWH(x + 3, y - 8, 2, 8), _px(0xFF6FA84B));
      canvas.drawRect(Rect.fromLTWH(x + 6, y - 5, 2, 5), _px(0xFF6FA84B));
    }
    const petals = [0xFFF2C230, 0xFFF07AA6, 0xFFFFF4E0, 0xFFD2BFF5];
    for (var i = 0; i < 26; i++) {
      final x = _snap(m.nextDouble() * (w - 8)), y = meadowTop + 14 + _snap(m.nextDouble() * (h - meadowTop - 30));
      final c = petals[m.nextInt(petals.length)];
      canvas.drawRect(Rect.fromLTWH(x, y + 2, 6, 2), _px(c));
      canvas.drawRect(Rect.fromLTWH(x + 2, y, 2, 6), _px(c));
      canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 2, 2), _px(0xFF6B4226));
    }
    final fenceBase = meadowTop + 6;
    canvas.drawRect(Rect.fromLTWH(0, fenceBase - 22, w, 4), _px(0xFFE9DCC2));
    canvas.drawRect(Rect.fromLTWH(0, fenceBase - 10, w, 4), _px(0xFFE9DCC2));
    for (var x = 6.0; x < w; x += 22) {
      canvas.drawRect(Rect.fromLTWH(x - 1, fenceBase - 32, 10, 34), _px(0xFF7A5E47));
      canvas.drawRect(Rect.fromLTWH(x, fenceBase - 30, 8, 30), _px(0xFFFBF3E4));
      canvas.drawRect(Rect.fromLTWH(x + 2, fenceBase - 34, 4, 4), _px(0xFFFBF3E4));
      canvas.drawRect(Rect.fromLTWH(x + 6, fenceBase - 30, 2, 30), _px(0xFFE2D3B6));
    }
  }

  @override
  bool shouldRepaint(LoginLandPainter old) => false;
}

/// The pergola: two posts, a beam with ivy (and flowers), two hanging
/// flower pots, and the hook in the middle.
class LoginPergolaPainter extends CustomPainter {
  LoginPergolaPainter({required this.beamTop, required this.sec, required this.shake});

  final double beamTop, sec, shake;
  static const double beamH = LoginLayout.beamH;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final postBottom = _snap(h * 0.64);
    for (final x in [6.0, w - 24]) {
      canvas.drawRect(Rect.fromLTWH(x - 2, beamTop, 22, postBottom - beamTop), _px(0xFF2B1A10));
      canvas.drawRect(Rect.fromLTWH(x, beamTop, 18, postBottom - beamTop), _px(0xFF8B5A34));
      canvas.drawRect(Rect.fromLTWH(x, beamTop, 4, postBottom - beamTop), _px(0xFFB97A45));
      canvas.drawRect(Rect.fromLTWH(x + 14, beamTop, 4, postBottom - beamTop), _px(0xFF6B4226));
      for (var y = beamTop + 30; y < postBottom - 10; y += 16) {
        final side = ((y / 16).round()).isEven ? -4.0 : 12.0;
        canvas.drawRect(Rect.fromLTWH(x + side, y, 9, 6), _px(0xFF5E9A3A));
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, beamTop - 3, w, beamH + 6), _px(0xFF2B1A10));
    canvas.drawRect(Rect.fromLTWH(0, beamTop, w, beamH), _px(0xFF8B5A34));
    canvas.drawRect(Rect.fromLTWH(0, beamTop, w, 3), _px(0xFFB97A45));
    canvas.drawRect(Rect.fromLTWH(0, beamTop + beamH - 3, w, 3), _px(0xFF6B4226));
    for (var x = 14.0; x < w; x += 58) {
      canvas.drawRect(Rect.fromLTWH(x, beamTop + 7, 24, 3), _px(0xFF7A4C2B));
    }
    final r = Random(4);
    for (var i = 0; i < 11; i++) {
      final x = _snap(r.nextDouble() * w, 3);
      final len = 3 + r.nextInt(6);
      final flowerAt = r.nextInt(len);
      if ((x - w / 2).abs() < 40) continue; // keep the hook clear
      for (var k = 0; k < len; k++) {
        final sway = (sin(sec * 1.4 + i) * k * 0.6 + shake * k * 0.8).roundToDouble();
        final y = beamTop + beamH + k * 9.0;
        canvas.drawRect(Rect.fromLTWH(x + sway, y, 3, 9), _px(0xFF4E7A2C));
        final side = k.isEven ? -6.0 : 3.0;
        canvas.drawRect(Rect.fromLTWH(x + sway + side, y + 2, 6, 5), _px(k % 3 == 0 ? 0xFF7CB350 : 0xFF5E9A3A));
        if (k == flowerAt) {
          canvas.drawRect(Rect.fromLTWH(x + sway - side - 2, y + 1, 6, 6), _px(i.isEven ? 0xFFF07AA6 : 0xFFFFF4E0));
          canvas.drawRect(Rect.fromLTWH(x + sway - side, y + 3, 2, 2), _px(0xFFF2C230));
        }
      }
    }
    for (final (fx, phase) in [(0.2, 0.0), (0.8, 1.7)]) {
      final top = Offset(_snap(w * fx), beamTop + beamH);
      final sway = sin(sec * 1.1 + phase) * 0.05 + shake * 0.02;
      const len = 34.0;
      final bottom = top + Offset(sin(sway) * len, cos(sway) * len);
      for (var k = 0; k < 5; k++) {
        final p = Offset.lerp(top, bottom, k / 4)!;
        canvas.drawRect(Rect.fromLTWH(_snap(p.dx, 2) - 1, p.dy, 3, 5), _px(0xFF4A4038));
      }
      final pot = Offset(_snap(bottom.dx, 2), bottom.dy);
      canvas.drawRect(Rect.fromLTWH(pot.dx - 12, pot.dy, 24, 4), _px(0xFF8E4A26));
      canvas.drawRect(Rect.fromLTWH(pot.dx - 10, pot.dy + 4, 20, 14), _px(0xFFC9713D));
      canvas.drawRect(Rect.fromLTWH(pot.dx - 10, pot.dy + 4, 4, 14), _px(0xFFE0915C));
      canvas.drawRect(Rect.fromLTWH(pot.dx + 6, pot.dy + 4, 4, 14), _px(0xFFA5582C));
      for (final (lx, ly, c) in [
        (-14.0, -6.0, 0xFF5E9A3A),
        (8.0, -8.0, 0xFF7CB350),
        (-4.0, -12.0, 0xFF5E9A3A),
        (-16.0, 6.0, 0xFF5E9A3A),
        (12.0, 4.0, 0xFF7CB350),
      ]) {
        canvas.drawRect(Rect.fromLTWH(pot.dx + lx, pot.dy + ly, 8, 6), _px(c));
      }
      final petal = fx < 0.5 ? 0xFFF07AA6 : 0xFFD2BFF5;
      for (final (lx, ly) in [(-8.0, -12.0), (4.0, -14.0), (12.0, -6.0)]) {
        canvas.drawRect(Rect.fromLTWH(pot.dx + lx, pot.dy + ly, 6, 6), _px(petal));
        canvas.drawRect(Rect.fromLTWH(pot.dx + lx + 2, pot.dy + ly + 2, 2, 2), _px(0xFFF2C230));
      }
    }
    final hx = w / 2 + shake;
    canvas.drawRect(Rect.fromLTWH(hx - 6, beamTop + beamH, 12, 4), _px(0xFF3E2A1B));
    canvas.drawRect(Rect.fromLTWH(hx - 1, beamTop + beamH + 4, 3, 6), _px(0xFF4A4038));
    canvas.drawRect(Rect.fromLTWH(hx - 4, beamTop + beamH + 9, 8, 3), _px(0xFF4A4038));
  }

  @override
  bool shouldRepaint(LoginPergolaPainter old) => old.sec != sec || old.shake != shake || old.beamTop != beamTop;
}

/// Flowering bushes tucked into the bottom corners.
class LoginBushesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Random(33);
    for (final (cx, cy, rad) in [(0.0, h + 6, 62.0), (w * 0.2, h + 26, 44.0), (w, h + 10, 66.0), (w * 0.82, h + 30, 40.0)]) {
      for (var y = -rad; y <= 0; y += 3) {
        final half = _snap(sqrt(max(0, rad * rad - y * y)), 3);
        canvas.drawRect(Rect.fromLTWH(cx - half, cy + y, half * 2, 3), _px(y < -rad * 0.75 ? 0xFF6BA544 : 0xFF5E9A3A));
      }
      for (var i = 0; i < 9; i++) {
        final a = pi + r.nextDouble() * pi;
        final d = rad * (0.4 + r.nextDouble() * 0.5);
        final p = Offset(cx + cos(a) * d, cy + sin(a) * d);
        final c = [0xFFF07AA6, 0xFFFFF4E0, 0xFFF2C230][r.nextInt(3)];
        canvas.drawRect(Rect.fromLTWH(_snap(p.dx, 2), _snap(p.dy, 2), 6, 6), _px(c));
        canvas.drawRect(Rect.fromLTWH(_snap(p.dx, 2) + 2, _snap(p.dy, 2) + 2, 2, 2), _px(0xFF6B4226));
      }
    }
  }

  @override
  bool shouldRepaint(LoginBushesPainter old) => false;
}

/// One leaf that keeps drifting down the screen.
class LeafDrift {
  const LeafDrift(this.x, this.speed, this.phase, this.color);

  final double x, speed, phase;
  final int color;

  static List<LeafDrift> scatter(Random r, int n) => [
        for (var i = 0; i < n; i++)
          LeafDrift(r.nextDouble(), 0.05 + r.nextDouble() * 0.05, r.nextDouble(),
              [0xFF7CB350, 0xFF5E9A3A, 0xFFA8D27F][r.nextInt(3)]),
      ];
}

/// Butterflies, leaves drifting down, and the burst of leaves the knock
/// shakes loose from the ivy.
class LoginLifePainter extends CustomPainter {
  LoginLifePainter({
    required this.sec,
    required this.leaves,
    required this.burstT,
    required this.burstFrom,
    required this.meadowTop,
  });

  final double sec;
  final List<LeafDrift> leaves;
  final double burstT; // seconds since the knock (−1 = not yet)
  final Offset burstFrom;
  final double meadowTop;

  void _leaf(Canvas canvas, Offset p, int color, bool flip) {
    final x = _snap(p.dx, 2), y = _snap(p.dy, 2);
    canvas.drawRect(Rect.fromLTWH(x, y, 6, 3), _px(color));
    canvas.drawRect(Rect.fromLTWH(x + (flip ? 0 : 3), y - 3, 3, 3), _px(color));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final l in leaves) {
      final t = (sec * l.speed + l.phase) % 1.0;
      final p = Offset(l.x * w + 22 * sin(sec * 1.2 + l.phase * 9), -10 + t * (h + 20));
      _leaf(canvas, p, l.color, sin(sec * 3 + l.phase * 5) > 0);
    }
    if (burstT >= 0 && burstT < 1.8) {
      final r = Random(77);
      for (var i = 0; i < 10; i++) {
        final vx = -60 + r.nextDouble() * 120, vy = -40 + r.nextDouble() * 30;
        final p = burstFrom +
            Offset((r.nextDouble() - 0.5) * 120 + vx * burstT + 10 * sin(burstT * 6 + i), vy * burstT + 70 * burstT * burstT);
        _leaf(canvas, p, i.isEven ? 0xFF7CB350 : 0xFF5E9A3A, (burstT * 8 + i).floor().isEven);
      }
    }
    for (final (i, color) in [(0, 0xFFF2C230), (1, 0xFFF07AA6)]) {
      final t = sec * 0.35 + i * 2.1;
      final p = Offset(w * (0.5 + 0.38 * sin(t * 0.9 + i)), meadowTop - 30 + 26 * sin(t * 1.7 + i * 2));
      final open = ((sec * 10 + i * 3).floor()).isEven;
      final x = _snap(p.dx, 2), y = _snap(p.dy, 2);
      canvas.drawRect(Rect.fromLTWH(x + 3, y, 2, 6), _px(0xFF3E2A1B));
      if (open) {
        canvas.drawRect(Rect.fromLTWH(x - 2, y - 1, 5, 4), _px(color));
        canvas.drawRect(Rect.fromLTWH(x + 5, y - 1, 5, 4), _px(color));
        canvas.drawRect(Rect.fromLTWH(x - 1, y + 3, 4, 3), _px(color));
        canvas.drawRect(Rect.fromLTWH(x + 5, y + 3, 4, 3), _px(color));
      } else {
        canvas.drawRect(Rect.fromLTWH(x + 1, y - 2, 2, 6), _px(color));
        canvas.drawRect(Rect.fromLTWH(x + 5, y - 2, 2, 6), _px(color));
      }
    }
  }

  @override
  bool shouldRepaint(LoginLifePainter old) => true;
}

/// Gold sparks popping off the hook when kuwago knocks it.
class KnockSparkPainter extends CustomPainter {
  KnockSparkPainter({required this.center, required this.t});

  final Offset center;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _pxa(0xFFE8B84B, sin(pi * t));
    for (var i = 0; i < 6; i++) {
      final a = -pi / 2 + (i - 2.5) * 0.5;
      final p = center + Offset(cos(a), sin(a)) * (8 + 14 * t);
      canvas.drawRect(Rect.fromCenter(center: p, width: 4, height: 4), paint);
    }
  }

  @override
  bool shouldRepaint(KnockSparkPainter old) => old.t != t;
}

/// Small parchment speech bubble for kuwago.
class OwlBubble extends StatelessWidget {
  const OwlBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: AppColors.parchment, border: Border.all(color: AppColors.panelDark, width: 2)),
      child: Text(text, style: AppTheme.pixelHeading(size: 8)),
    );
  }
}

/// A small parchment ribbon label with notched ends.
class RibbonTag extends StatelessWidget {
  const RibbonTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RibbonEnd(left: true),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.parchment,
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.panelDark, width: 2)),
          ),
          child: Text(text, style: AppTheme.body(size: 12, color: AppColors.greenDeep, weight: FontWeight.w900)),
        ),
        const _RibbonEnd(left: false),
      ],
    );
  }
}

class _RibbonEnd extends StatelessWidget {
  const _RibbonEnd({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(12, 31), painter: _RibbonEndPainter(left));
}

class _RibbonEndPainter extends CustomPainter {
  _RibbonEndPainter(this.left);

  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    // Rows of a swallow-tail end, drawn in 3-px steps.
    for (var y = 0.0; y < size.height; y += 3) {
      final notch = (size.height / 2 - (y - size.height / 2 + 1.5).abs()) / (size.height / 2) * 6;
      final inset = _snap(notch, 3);
      final rect = left ? Rect.fromLTWH(inset, y, size.width - inset, 3) : Rect.fromLTWH(0, y, size.width - inset, 3);
      canvas.drawRect(rect, _px(0xFF3E2A1B));
      canvas.drawRect(
          rect.translate(left ? 2 : 0, 0).intersect(Rect.fromLTWH(0, 2, size.width, size.height - 4)), _px(0xFFE2C69C));
    }
  }

  @override
  bool shouldRepaint(_RibbonEndPainter old) => false;
}
