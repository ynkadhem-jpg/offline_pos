import 'package:flutter/material.dart';

/// Central color definitions for the light theme.
///
/// These tokens define the product identity: calm financial navy, warm coral
/// actions, soft surfaces, and semantic status colors.
abstract final class AppColors {
  static const Color primary = Color(0xFF183B56);
  static const Color primaryHover = Color(0xFF244F73);
  static const Color accent = Color(0xFFFF7A45);
  static const Color accentSoft = Color(0xFFFFE8DD);

  static const Color surfacePage = Color(0xFFF6F8FB);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceTint = Color(0xFFEAF1F8);

  static const Color ink = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color inkSoft = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE8F7EE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFF4D6);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFEFF6FF);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappSoft = Color(0xFFE7F8EE);

  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartTeal = Color(0xFF14B8A6);
  static const Color chartPurple = Color(0xFF8B5CF6);
  static const Color chartAmber = Color(0xFFF59E0B);

  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        tertiary: accent,
        surface: surfacePage,
        error: error,
      ).copyWith(
        onPrimary: Colors.white,
        onTertiary: Colors.white,
        onSurface: ink,
        onSurfaceVariant: inkMuted,
        outline: borderStrong,
        outlineVariant: border,
      );
}
