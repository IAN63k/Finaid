import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/onboarding_screen.dart';

class FinaidApp extends ConsumerStatefulWidget {
  const FinaidApp({super.key});

  @override
  ConsumerState<FinaidApp> createState() => _FinaidAppState();
}

class _FinaidAppState extends ConsumerState<FinaidApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).pushToPlatform();
      ref.read(ingestionServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Finaid',
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
