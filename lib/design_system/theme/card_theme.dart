import 'package:flutter/material.dart';

import '../tokens/app_elevation.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

abstract final class CardThemeConfig {
  static CardThemeData data({required ColorScheme colorScheme}) {
    return CardThemeData(
      elevation: AppElevation.card,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}
