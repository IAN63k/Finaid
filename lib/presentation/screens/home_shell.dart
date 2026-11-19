import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_lock.dart';
import '../../application/providers.dart';
import '../../domain/entities/insight.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'trends_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  /// Atrás del teléfono: desde otra pestaña vuelve a Inicio; en Inicio pide
  /// confirmación antes de cerrar la app. Las hojas y páginas abiertas encima
  /// se cierran antes de llegar aquí, porque son rutas propias.
  Future<void> _handleBack() async {
    // Con la app bloqueada no se muestra nada: atrás la manda al fondo.
    if (ref.read(appLockProvider)) {
      await SystemNavigator.pop();
      return;
    }
    if (_index != 0) {
      _go(0);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('¿Salir de Finaid?'),
        content: const Text(
            'Tus movimientos se siguen registrando en segundo plano aunque cierres la app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (exit == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount = ref.watch(reviewCountProvider);
    final warnings = ref
        .watch(insightsProvider)
        .where((i) => i.severity == InsightSeverity.warning)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onSeeTransactions: () => _go(1),
            onSeeInsights: () => _go(3),
            onOpenSettings: () => _go(4),
          ),
          const TransactionsScreen(),
          const TrendsScreen(),
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
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Tendencias',
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
      ),
    );
  }
}
