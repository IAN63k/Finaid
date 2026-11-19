import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_lock.dart';
import '../../core/external_launch.dart';
import '../../infrastructure/platform/device_auth.dart';
import 'finaid_logo.dart';

/// Cubre toda la app (incluidas las páginas abiertas encima) cuando está
/// bloqueada, y avisa al controlador de bloqueo de las idas y vueltas a
/// segundo plano. Se coloca en `MaterialApp.builder`.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ExternalLaunch.onLaunch =
        () => ref.read(appLockProvider.notifier).allowNextResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ExternalLaunch.onLaunch = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        lock.onBackground();
      case AppLifecycleState.resumed:
        lock.onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        // El contenido sigue montado (no se pierde la navegación), pero no se
        // pinta ni recibe toques mientras está bloqueado.
        Offstage(offstage: locked, child: widget.child),
        if (locked) const _LockScreen(),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Pedir la huella apenas aparece la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await ref.read(appLockProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (outcome) {
        AuthOutcome.lockout =>
          'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
        AuthOutcome.error => 'No se pudo verificar. Inténtalo de nuevo.',
        AuthOutcome.unavailable =>
          'Tu teléfono ya no tiene bloqueo de pantalla, así que se desactivó el de Finaid.',
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              const FinaidLogo(size: 88),
              const SizedBox(height: 24),
              Text('Finaid está bloqueada',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Usa tu huella, tu rostro o el PIN del teléfono para ver tus movimientos.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!,
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                    textAlign: TextAlign.center),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tus compras se siguen registrando aunque la app esté bloqueada.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
