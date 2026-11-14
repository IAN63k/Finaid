import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final android = ref.watch(androidSourceProvider);
    final granted = ref.watch(permissionStatusProvider).valueOrNull ?? false;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.account_balance_wallet_outlined,
                    size: 34, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text('Tus gastos, solos.',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Finaid lee las notificaciones de compra de tus bancos y las convierte en movimientos categorizados, con consejos para gastar mejor.',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              const _Feature(
                icon: Icons.lock_outline,
                title: 'Sin contraseñas bancarias',
                body:
                    'No te pedimos usuario ni clave. Solo leemos el texto de la notificación.',
              ),
              const _Feature(
                icon: Icons.phone_android,
                title: 'Todo en tu teléfono',
                body:
                    'No hay servidor. Tu historial nunca sale del dispositivo.',
              ),
              const _Feature(
                icon: Icons.auto_awesome_outlined,
                title: 'Categorías y consejos automáticos',
                body:
                    'Mercado, transporte, suscripciones… y alertas cuando algo se sale de lo normal.',
              ),
              const Spacer(flex: 2),
              if (android != null) ...[
                FilledButton.icon(
                  onPressed: granted
                      ? null
                      : () async {
                          await android.requestPermission();
                        },
                  icon: Icon(granted ? Icons.check : Icons.notifications_active_outlined),
                  label: Text(granted
                      ? 'Acceso a notificaciones concedido'
                      : 'Permitir acceso a notificaciones'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Android abrirá la lista de apps con acceso a notificaciones. Activa "Finaid" y vuelve.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () =>
                    ref.read(settingsProvider.notifier).completeOnboarding(),
                child: Text(granted || android == null
                    ? 'Empezar'
                    : 'Continuar sin permiso por ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(body,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
