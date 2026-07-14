import 'package:flutter/material.dart';

import '../services/database.dart';
import 'accounts.dart';
import 'customers.dart';
import 'products.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late final AppDatabase _database = AppDatabase();

  List<Widget> get _screens => [
    ProductsScreen(database: _database),
    CustomersScreen(database: _database),
    AccountsScreen(database: _database),
  ];

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'المنتجات',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'الزبائن'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'الحسابات',
          ),
        ],
      ),
    );
  }
}
