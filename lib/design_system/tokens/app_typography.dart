import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens using IBM Plex Sans Arabic.
///
/// TODO(offline-fonts): Bundle IBM Plex Sans Arabic in assets for guaranteed
/// offline availability instead of relying on google_fonts network download.
abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme colorScheme) {
    final base = ThemeData(brightness: colorScheme.brightness).textTheme;
    final arabic = GoogleFonts.ibmPlexSansArabicTextTheme(base);
    return arabic.copyWith(
      titleLarge: arabic.titleLarge?.copyWith(fontSize: 24),
      titleMedium: arabic.titleMedium?.copyWith(fontSize: 20),
      bodyLarge: arabic.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: arabic.bodyMedium?.copyWith(fontSize: 16),
      labelLarge: arabic.labelLarge?.copyWith(fontSize: 16),
      labelMedium: arabic.labelMedium?.copyWith(fontSize: 14),
    );
  }
}
