import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/insight.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final reviewCount = ref.watch(reviewCountProvider);
    final warnings = ref
        .watch(insightsProvider)
        .where((i) => i.severity == InsightSeverity.warning)
        .length;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onSeeTransactions: () => _go(1),
            onSeeInsights: () => _go(2),
            onOpenSettings: () => _go(3),
          ),
          const TransactionsScreen(),
          const InsightsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: reviewCount > 0,
              label: Text('$reviewCount'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: warnings > 0,
              label: Text('$warnings'),
              child: const Icon(Icons.lightbulb_outline),
            ),
            selectedIcon: const Icon(Icons.lightbulb),
            label: 'Consejos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
