import 'package:flutter/foundation.dart';

/// Aviso de que Finaid está por abrir una pantalla del sistema (selector de
/// archivos, ajustes de Android, diálogo de permisos…). La app pasa a segundo
/// plano y vuelve, y el bloqueo no debe pedir la huella por eso.
///
/// La capa de infraestructura llama a [notify] antes de lanzar esas pantallas y
/// la aplicación registra [onLaunch] (ver `AppLockNotifier.allowNextResume`).
class ExternalLaunch {
  ExternalLaunch._();

  static VoidCallback? onLaunch;

  static void notify() => onLaunch?.call();
}
