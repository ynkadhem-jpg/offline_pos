import 'package:flutter/material.dart';

import '../tokens/app_elevation.dart';

abstract final class AppBarThemeConfig {
  static AppBarTheme data({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return AppBarTheme(
      elevation: AppElevation.flat,
      scrolledUnderElevation: AppElevation.raised,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    );
  }
}
