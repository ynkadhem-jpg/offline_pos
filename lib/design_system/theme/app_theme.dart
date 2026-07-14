import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'app_bar_theme.dart';
import 'button_theme.dart';
import 'card_theme.dart';
import 'input_theme.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = AppColors.lightScheme;
    final textTheme = AppTypography.textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarThemeConfig.data(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      cardTheme: CardThemeConfig.data(colorScheme: colorScheme),
      elevatedButtonTheme: ButtonThemeConfig.elevated(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      filledButtonTheme: ButtonThemeConfig.filled(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      outlinedButtonTheme: ButtonThemeConfig.outlined(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      textButtonTheme: ButtonThemeConfig.text(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      inputDecorationTheme: InputThemeConfig.data(
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
      ),
    );
  }
}
