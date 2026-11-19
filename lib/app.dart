import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_lock.dart';
import 'application/providers.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/widgets/app_lock_gate.dart';

class FinaidApp extends ConsumerStatefulWidget {
  const FinaidApp({super.key});

  @override
  ConsumerState<FinaidApp> createState() => _FinaidAppState();
}

class _FinaidAppState extends ConsumerState<FinaidApp> {
  /// Para mostrar alertas (presupuesto) sobre cualquier pantalla.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  void _showAlert(ForegroundAlert alert) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final a = alert.alert;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(a.body),
          ],
        ),
      ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = ref.read(settingsProvider.notifier);
      // Persistir (incluye la migración de packages nuevos) y sincronizar.
      await settings.completeLoadSync();
      await settings.autoEnableDetectedBanks();
      await ref.read(ingestionServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    ref.listen<ForegroundAlert?>(foregroundAlertProvider, (_, next) {
      // Con la app bloqueada no se muestran montos en pantalla.
      if (next != null && !ref.read(appLockProvider)) _showAlert(next);
    });
    return MaterialApp(
      title: 'Finaid',
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.onboardingDone
          ? const HomeShell()
          : const OnboardingScreen(),
    );
  }
}
