import 'dart:async';

import 'package:flutter/material.dart';

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
    ),
    ProductsScreen(
      key: ValueKey('products_$_databaseGeneration'),
      database: _database,
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
        final content = IndexedStack(index: _selectedIndex, children: _screens);
        return Scaffold(
          body: useRail
              ? Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      extended: constraints.maxWidth >= 1100,
                      labelType: constraints.maxWidth >= 1100
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Icon(
                          Icons.point_of_sale,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('لوحة التحكم'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('الزبائن'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: Text('المنتجات'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.bar_chart_outlined),
                          selectedIcon: Icon(Icons.bar_chart),
                          label: Text('التقارير'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('الإعدادات'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
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
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'لوحة التحكم',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'الزبائن',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'المنتجات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: 'التقارير',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'الإعدادات',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
