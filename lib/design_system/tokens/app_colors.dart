import 'package:flutter/material.dart';

/// Central color definitions for the light theme.
///
/// Material colors are generated from a seed color. Semantic colors are
/// defined separately for domain-specific UI (e.g. payment status).
abstract final class AppColors {
  static const Color seed = Color(0xFF1565C0);
  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  // Semantic colors for future payment/status UI.
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);
}
