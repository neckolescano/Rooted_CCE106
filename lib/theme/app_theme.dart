import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's name, in ONE place. Change it here and the app title and
/// "About" text update. The big logo is the KuwagoLogo widget (its O is a
/// clock), and the name under the icon on the phone is android:label in
/// android/app/src/main/AndroidManifest.xml.
class AppInfo {
  AppInfo._();

  static const name = 'kuwaGO';
  static const tagline = 'Plant Edition';
}

/// All the colors from the Figma design in one place.
/// Change a value here and it updates everywhere in the app.
class AppColors {
  AppColors._(); // no instances, just constants

  static const Color background = Color(0xFFF3E8D2); // cream page background
  static const Color panelDark = Color(0xFF3E2A1B); // darkest brown (top bar / border)
  static const Color panelMedium = Color(0xFF8B5A34); // medium brown (cards, buttons)
  static const Color panelLight = Color(0xFFB97A45); // lighter brown (button highlight)
  static const Color accentGold = Color(0xFFE8B84B); // gold text / streak numbers
  static const Color accentGreen = Color(0xFF7CB350); // "cozy meadow" green label
  static const Color textCream = Color(0xFFF3E8D2); // light text on dark backgrounds
  static const Color textDark = Color(0xFF3E2A1B); // dark text on light backgrounds

  // --- Added in the redesign. Same palette, just named shades so screens
  // --- stop hardcoding their own hex values.

  /// Warm paper color — the plant box on Home, the garden row, journal pages.
  /// (Was hardcoded as 0xFFF6DFC0 in a few screens.)
  static const Color parchment = Color(0xFFF6DFC0);

  /// Darker paper, for ruled lines and edges drawn on parchment.
  static const Color parchmentShade = Color(0xFFE2C69C);

  /// accentGreen is too light to read on cream (contrast ~2:1). Use this
  /// darker leaf green for green TEXT on light backgrounds.
  static const Color greenDeep = Color(0xFF4E7A2C);

  /// Red wash for "danger" actions like Give Up (the tint already used on
  /// that button), and a darker red that's readable as error text.
  static const Color danger = Color(0xFFCC6B5C);
  static const Color dangerText = Color(0xFFB23B2E);

  /// Secondary text on light backgrounds (hints, captions).
  static const Color textMuted = Color(0xFF7A5E47);

  /// Dim layer behind popups. Dark enough that the popup is clearly the
  /// focus, light enough that the scene is still visible behind it.
  static const Color overlay = Color(0xB3000000); // 70% black
}

/// Spacing scale. Use these instead of random numbers so every screen has
/// the same rhythm. Everything is a multiple of 4.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Padding around the edge of every main screen.
  static const EdgeInsets screen = EdgeInsets.all(lg);
}

/// Border + corner treatment shared by panels, tiles and chips.
class AppBorders {
  AppBorders._();

  static const double width = 2;

  /// Current look. Phase 2 swaps panels to square pixel corners, but this
  /// stays as the single place to change it.
  static const double radius = 4;
}

/// Fixed sizes that several screens need to agree on.
class AppSizes {
  AppSizes._();

  /// Smallest comfortable tap area (Android accessibility guideline).
  static const double minTouchTarget = 48;

  static const double buttonHeight = 52;
  static const double bottomNavHeight = 76;

  /// Pixel-art rule: 1 art pixel = 2 dp on screen. A 128px plant sprite
  /// shows at 256 dp; a 208x448 background fills a phone. Keeping one
  /// scale is what makes all the art look like it's from the same game.
  static const double artScale = 2;
}

/// The text hierarchy. Every piece of text in the app should use one of
/// these, so headings/labels/body look the same on every screen.
///
///   Pixel font (Press Start 2P) → titles, timers, big game moments
///   Nunito                      → everything people actually read
class AppText {
  AppText._();

  /// Screen title, e.g. "Study Notes", "STUDY BUDDY".
  static TextStyle screenTitle({Color color = AppColors.textDark}) =>
      AppTheme.pixelHeading(size: 15, color: color);

  /// Big celebration text, e.g. "CORRECT!", "You did it!".
  static TextStyle gameMoment({Color color = AppColors.textDark}) =>
      AppTheme.pixelHeading(size: 12, color: color);

  /// The big countdown on the Timer screen.
  static TextStyle timerLarge({Color color = AppColors.textCream}) =>
      AppTheme.pixelHeading(size: 40, color: color);

  /// The small countdown in the Notes header.
  static TextStyle timerCompact({Color color = AppColors.textCream}) =>
      AppTheme.pixelHeading(size: 18, color: color);

  /// Section label above a group, e.g. "COZY SETTINGS". Write it in caps.
  static TextStyle sectionLabel({Color color = AppColors.textDark}) =>
      AppTheme.body(size: 13, color: color, weight: FontWeight.w800);

  /// Title inside a panel, e.g. "GARDEN ARCHIVE", "Push Reminders".
  static TextStyle panelTitle({Color color = AppColors.textCream}) =>
      AppTheme.body(size: 13, color: color, weight: FontWeight.bold);

  /// Normal reading text.
  static TextStyle body({Color color = AppColors.textDark}) =>
      AppTheme.body(size: 14, color: color);

  /// Stats and secondary lines, e.g. "Total: 9 sessions".
  static TextStyle small({Color color = AppColors.textDark, FontWeight weight = FontWeight.w600}) =>
      AppTheme.body(size: 12, color: color, weight: weight);

  /// Tiny print, e.g. "#1" under a garden tile. Don't go smaller than this.
  static TextStyle caption({Color color = AppColors.textMuted}) =>
      AppTheme.body(size: 11, color: color, weight: FontWeight.w600);
}

class AppTheme {
  AppTheme._();

  /// Heading font — the blocky pixel-style font used for titles.
  static TextStyle pixelHeading({double size = 22, Color color = AppColors.textDark}) {
    return GoogleFonts.pressStart2p(
      fontSize: size,
      color: color,
      height: 1.4,
    );
  }

  /// Body font — a normal, easy-to-read font for everything else.
  static TextStyle body({double size = 14, Color color = AppColors.textDark, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.nunito(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.nunito().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.panelMedium,
        primary: AppColors.panelMedium,
        // `background` is deprecated in Material 3 — `surface` is its
        // replacement (it's what dialogs and sheets paint with).
        surface: AppColors.background,
      ),
      // Default snackbars match the game style until PixelToast replaces them.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panelDark,
        contentTextStyle: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
      ),
      useMaterial3: true,
    );
  }
}
