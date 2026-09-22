import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        background: AppColors.background,
      ),
      useMaterial3: true,
    );
  }
}
