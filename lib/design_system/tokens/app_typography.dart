import 'package:flutter/material.dart';

/// Typography tokens using the device's Arabic-capable system font.
/// This keeps the first frame fully offline and avoids runtime font downloads.
abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme colorScheme) {
    final base = ThemeData(brightness: colorScheme.brightness).textTheme;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 17,
        height: 1.55,
        color: colorScheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.5,
        color: colorScheme.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
