import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_radius.dart';

abstract final class CardThemeConfig {
  static CardThemeData data({required ColorScheme colorScheme}) {
    return CardThemeData(
      elevation: AppElevation.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.primary.withValues(alpha: 0.10),
      color: AppColors.surfaceCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
