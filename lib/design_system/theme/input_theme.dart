import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

abstract final class InputThemeConfig {
  static InputDecorationTheme data({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final borderRadius = BorderRadius.circular(AppRadius.md);

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.rg,
      ),
      border: OutlineInputBorder(borderRadius: borderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
      ),
    );
  }
}
