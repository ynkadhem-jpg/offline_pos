import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/automatic_backup_service.dart';
import '../services/automatic_backup_storage.dart';
import '../services/database.dart';
import '../services/local_backup_service.dart';
import 'accounts.dart';
import 'customers.dart';
import 'dashboard.dart';
import 'products.dart';
import 'settings.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  AppDatabase _database = AppDatabase();
  final LocalBackupService _backupService = LocalBackupService();
  late final AutomaticBackupService _automaticBackupService;
  int _databaseGeneration = 0;

  static const _destinations = [
    _ShellDestination(
      label: 'لوحة التحكم',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _ShellDestination(
      label: 'الزبائن',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _ShellDestination(
      label: 'المنتجات',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _ShellDestination(
      label: 'التقارير',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
    _ShellDestination(
      label: 'النسخ الاحتياطي',
      icon: Icons.backup_outlined,
      selectedIcon: Icons.backup,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _automaticBackupService = AutomaticBackupService(
      localBackupService: _backupService,
      storage: const AndroidAutomaticBackupStorage(),
      timestampStore: SharedPreferencesAutomaticBackupTimestampStore(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_automaticBackupService.runIfDue(_database));
      }
    });
  }

  List<Widget> get _screens => [
    DashboardScreen(
      key: ValueKey('dashboard_$_databaseGeneration'),
      database: _database,
    ),
    CustomersScreen(
      key: ValueKey('customers_$_databaseGeneration'),
      database: _database,
      onDataChanged: _createImmediateBackup,
    ),
    ProductsScreen(
      key: ValueKey('products_$_databaseGeneration'),
      database: _database,
      onDataChanged: _createImmediateBackup,
    ),
    AccountsScreen(
      key: ValueKey('accounts_$_databaseGeneration'),
      database: _database,
    ),
    SettingsScreen(
      key: ValueKey('settings_$_databaseGeneration'),
      database: _database,
      backupService: _backupService,
      onDatabaseChanged: _replaceDatabase,
    ),
  ];

  void _replaceDatabase(AppDatabase database) {
    setState(() {
      _database = database;
      _databaseGeneration++;
    });
  }

  Future<void> _createImmediateBackup() async {
    await _automaticBackupService.runNow(_database);
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 800;
        final screens = _screens;
        final content = DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: IndexedStack(index: _selectedIndex, children: screens),
        );

        return Scaffold(
          body: useRail
              ? Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _ShellRail(
                      selectedIndex: _selectedIndex,
                      extended: constraints.maxWidth >= 1120,
                      onSelected: (index) =>
                          setState(() => _selectedIndex = index),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: extended ? 274 : 112,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(AppRadius.xl),
            bottomStart: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              children: [
                Container(
                  width: AppSpacing.xxl + AppSpacing.md,
                  height: AppSpacing.xxl + AppSpacing.md,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/branding/app_logo.png',
                    fit: BoxFit.cover,
                    semanticLabel: 'شعار تقسيط',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (extended)
                  Text(
                    'تقسيط',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                SizedBox(height: extended ? AppSpacing.xxl : AppSpacing.xl),
                Expanded(
                  child: Column(
                    children: [
                      _RailItem(
                        destination: _MainShellState._destinations[0],
                        selected: selectedIndex == 0,
                        extended: extended,
                        onTap: () => onSelected(0),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RailItem(
                        destination: _MainShellState._destinations[1],
                        selected: selectedIndex == 1,
                        extended: extended,
                        onTap: () => onSelected(1),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RailItem(
                        destination: _MainShellState._destinations[2],
                        selected: selectedIndex == 2,
                        extended: extended,
                        onTap: () => onSelected(2),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RailItem(
                        destination: _MainShellState._destinations[3],
                        selected: selectedIndex == 3,
                        extended: extended,
                        onTap: () => onSelected(3),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RailItem(
                        destination: _MainShellState._destinations[4],
                        selected: selectedIndex == 4,
                        extended: extended,
                        onTap: () => onSelected(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.72);
    final background = selected
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.transparent;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: AppSpacing.minTouchTarget),
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: foreground,
                ),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
