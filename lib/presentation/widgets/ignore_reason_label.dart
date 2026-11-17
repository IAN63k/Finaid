/// Texto legible para los motivos de descarte del parser.
String ignoreReasonLabel(String? reason) => switch (reason) {
      'codigo_seguridad' => 'Es un código de seguridad / OTP',
      'rechazada' => 'Transacción rechazada o fallida',
      'promocion' => 'Parece una promoción',
      'recordatorio' => 'Es un recordatorio de pago',
      'seguridad' => 'Aviso de seguridad (inicio de sesión, bloqueo…)',
      'sin_monto' => 'No se encontró un monto',
      'sin_verbo' => 'No parece una compra, pago o transferencia',
      'notificacion_repetida' => 'La misma notificación ya se había procesado',
      'movimiento_repetido' =>
        'Ya existe un movimiento igual (push + SMS del mismo banco)',
      null => 'Sin motivo registrado',
      _ => reason,
    };

String statusLabel(String status) => switch (status) {
      'parsed' => 'Registrada',
      'ignored' => 'Ignorada',
      'duplicate' => 'Duplicada',
      _ => 'Pendiente',
    };
