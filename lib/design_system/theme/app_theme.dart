import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
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
      scaffoldBackgroundColor: AppColors.surfacePage,
      visualDensity: VisualDensity.standard,
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
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.primary),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceMuted),
        headingTextStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primary,
        indicatorColor: Colors.white.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withValues(alpha: 0.70),
        ),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.74),
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: AppColors.surfaceCard,
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inkMuted,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
      ),
    );
  }
}
