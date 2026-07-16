import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/tokens/app_spacing.dart';
import '../services/license_model.dart';
import '../services/license_service.dart';
import 'activation_screen.dart';
import 'clock_tampering_screen.dart';
import 'main_shell.dart';
import 'trial_expired_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), _openApp);
  }

  Future<void> _openApp() async {
    final licenseService = LicenseService();
    await licenseService.initialize();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) {
          return switch (licenseService.status) {
            LicenseStatus.active => const MainShell(),
            LicenseStatus.trialExpired => TrialExpiredScreen(
              licenseService: licenseService,
            ),
            LicenseStatus.clockTampered => ClockTamperingScreen(
              licenseService: licenseService,
            ),
            LicenseStatus.unactivated => ActivationScreen(
              licenseService: licenseService,
            ),
          };
        },
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/branding/app_logo.png',
                  width: 260,
                  semanticLabel: 'شعار تقسيط',
                ),
                const SizedBox(height: 12),
                Text(
                  'تقسيط',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'إدارة الأقساط بسهولة واحترافية',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: AppSpacing.xl,
                  height: AppSpacing.xl,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
