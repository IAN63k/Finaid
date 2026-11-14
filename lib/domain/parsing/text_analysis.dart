import '../entities/transaction.dart';

/// Resultado de detectar el tipo de movimiento a partir de los verbos.
typedef KindDetection = ({TransactionKind kind, bool strong});

bool _anyWord(String text, List<String> keywords) {
  for (final kw in keywords) {
    if (RegExp('(?:^|[^a-z])${RegExp.escape(kw)}').hasMatch(text)) return true;
  }
  return false;
}

/// Detecta el tipo de transacción en texto normalizado (minúsculas, sin tildes).
class KindDetector {
  KindDetector._();

  static const _refund = [
    'reembolso',
    'devolucion',
    'reversion',
    'reverso',
    'te devolvimos',
    'reintegro',
  ];
  static const _income = [
    'recibiste',
    'te llegaron',
    'te llego ',
    'te enviaron',
    'te transfirieron',
    'te consignaron',
    'consignacion',
    'abono a tu cuenta',
    'abono en tu cuenta',
    'abono de nomina',
    'abono recibido',
    'transferencia recibida',
    'nomina',
    'te pagaron',
    'ingreso a tu cuenta',
    'deposito',
    'te mandaron',
    'pago recibido',
    'recepcion de',
  ];
  static final _incomeRegex = RegExp(r'transferencia de (?![$\d])');
  static const _withdrawal = [
    'retiraste',
    'retiro',
    'sacaste',
    'cajero',
    'avance en efectivo',
    'avance de efectivo',
  ];
  static const _transferOut = [
    'transferiste',
    'enviaste',
    'pasaste',
    'transferencia a ',
    'envio de dinero',
    'giro',
    'le enviaste',
    'enviado a',
    'envio a ',
    'transferencia exitosa',
    'transferencia realizada',
    'plata enviada',
    'mandaste',
  ];
  static final _transferOutRegex = RegExp(r'transferencia (?:de|por) [$\d]');
  static const _purchase = [
    'compraste',
    'compra ',
    'compra:',
    'compra.',
    'compra,',
    'pago en ',
    'pagaste en ',
    'pago con tarjeta',
    'pago con tu tarjeta',
    'usaste tu tarjeta',
    'transaccion aprobada',
    'pago aprobado',
    'purchase',
    'pagaste con',
    'consumo',
    'cargo por',
    'cobro de',
  ];
  static final _purchaseRegex =
      RegExp(r'pagaste \S+ (?:en|a) (?!tu |la |el |su )');
  static const _bill = [
    'factura',
    'pse',
    'pago de',
    'pagaste',
    'cuota',
    'servicio',
    'pago exitoso',
    'pago realizado',
    'recarga',
    'abono a tarjeta',
    'abono a tu tarjeta',
  ];

  static KindDetection detect(String t) {
    if (_anyWord(t, _refund)) {
      return (kind: TransactionKind.refund, strong: true);
    }
    if (_anyWord(t, _income) || _incomeRegex.hasMatch(t)) {
      return (kind: TransactionKind.transferIn, strong: true);
    }
    if (_anyWord(t, _withdrawal)) {
      return (kind: TransactionKind.withdrawal, strong: true);
    }
    if (_anyWord(t, _transferOut) || _transferOutRegex.hasMatch(t)) {
      return (kind: TransactionKind.transferOut, strong: true);
    }
    if (_anyWord(t, _purchase) || _purchaseRegex.hasMatch(t)) {
      return (kind: TransactionKind.purchase, strong: true);
    }
    if (_anyWord(t, _bill)) {
      return (kind: TransactionKind.billPayment, strong: false);
    }
    return (kind: TransactionKind.unknown, strong: false);
  }
}

/// Decide si una notificación es ruido (OTP, promociones, rechazos...).
class NoiseFilter {
  NoiseFilter._();

  static const _otp = [
    'codigo de verificacion',
    'codigo de seguridad',
    'clave dinamica',
    'clave temporal',
    'codigo otp',
    'tu codigo es',
    'el codigo es',
    'codigo para',
    'no compartas',
    'no lo compartas',
    'token de seguridad',
    'codigo de acceso',
    'codigo de confirmacion',
    'contrasena',
  ];
  static const _rejected = [
    'rechazad',
    'declinad',
    'no fue posible',
    'fallid',
    'no aprobad',
    'no se pudo',
    'intento de',
    'denegad',
    'fondos insuficientes',
    'sin fondos',
    'no exitos',
  ];
  static const _reminder = [
    'recuerda pagar',
    'fecha limite',
    'pago minimo',
    'vence el',
    'proximo pago',
    'esta por vencer',
    'tu extracto',
  ];
  static const _security = [
    'inicio de sesion',
    'iniciaste sesion',
    'ingresaste a',
    'cambio de clave',
    'nuevo dispositivo',
    'bloqueamos',
    'bloqueo de',
  ];
  static const _promo = [
    'descuento',
    'promocion',
    'gana ',
    'participa',
    'oferta',
    'preaprobado',
    'sorteo',
    'te invitamos',
    'conoce',
    'novedad',
  ];
  static const _transactionalHints = [
    'aprobad',
    'exitos',
    'realiz',
    'transaccion',
    'movimiento',
    'cargo',
    'debito',
    'credito a',
  ];

  /// Devuelve la razón para ignorar o `null` si parece una transacción.
  static String? reason(String t, {required bool hasVerb}) {
    if (_anyWord(t, _otp)) return 'codigo_seguridad';
    if (_anyWord(t, _rejected)) return 'rechazada';
    if (!hasVerb) {
      if (_anyWord(t, _security)) return 'seguridad';
      if (_anyWord(t, _reminder)) return 'recordatorio';
      if (_anyWord(t, _promo)) return 'promocion';
    }
    return null;
  }

  /// Sin verbo claro pero con pinta de movimiento ("transacción aprobada").
  static bool looksTransactional(String t) => _anyWord(t, _transactionalHints);
}

/// Extrae el comercio o la contraparte ("en EXITO", "a Juan Pérez", "de María").
class CounterpartyExtractor {
  CounterpartyExtractor._();

  static final RegExp _processorPrefix = RegExp(
    r'^(?:payu|dlo|dlocal|merpago|mercadopago|mp|paypal|sumup|sq|sqc|ebanx|stripe|wompi|epayco|payvalida|adyen|bold|pagos?)\s*\*\s*',
    caseSensitive: false,
  );

  static final RegExp _cutAt = RegExp(
    r'\s+(?:con\s|desde\s|por\s|a\s+las\s|hoy\b|ayer\b|el\s+(?:dia\s+)?\d|'
    r'tarjeta\b|t\.\s?[cd]|tc\b|td\b|tdc\b|tdb\b|cta\b|cuenta\b|ref\b|'
    r'saldo\b|cupo\b|si\s+no\b|puedes\b|usando\b|mediante\b|via\b|'
    r'aprobad[ao]\b|exitos[ao]\b|realizad[ao]\b|terminada\b|'
    r'en\s+tu\b|a\s+tu\b|de\s+tu\b|en\s+la\s+cuenta\b|'
    r'\*|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}:\d{2}|\$|cop\b)'
    r'|[,;:!?¿¡\n]|\.(?=\s|$)',
    caseSensitive: false,
  );

  static const _stopwords = {
    'tu', 'su', 'la', 'el', 'las', 'los', 'un', 'una', 'the', 'tus',
    'cuenta', 'tarjeta', 'nequi', 'bancolombia', 'daviplata', 'cajero',
  };

  /// [text] debe venir sin tildes (conservando mayúsculas). [from] es la
  /// posición donde terminó el monto; primero se busca después de él.
  static String? extract(String text, TransactionKind kind, {int from = 0}) {
    final preps = switch (kind) {
      TransactionKind.transferOut => const ['a', 'para', 'hacia'],
      TransactionKind.transferIn => const ['de', 'desde'],
      TransactionKind.refund => const ['de', 'en'],
      TransactionKind.withdrawal => const ['en'],
      TransactionKind.billPayment => const [
          'factura de',
          'factura',
          'servicio de',
          'recarga a',
          'recarga',
          'en',
          'a',
          'de',
        ],
      _ => const ['en', 'a'],
    };
    final after = from > 0 && from < text.length ? text.substring(from) : '';
    for (final prep in preps) {
      final regex = _prepRegex(prep);
      final candidates = <String>[
        if (after.isNotEmpty) after,
        text,
      ];
      for (final hay in candidates) {
        final m = regex.firstMatch(hay);
        if (m == null) continue;
        final cleaned = clean(m.group(1)!);
        if (cleaned.length >= 2 &&
            !_stopwords.contains(cleaned.toLowerCase()) &&
            RegExp(r'[A-Za-z]').hasMatch(cleaned)) {
          return cleaned;
        }
      }
    }
    return null;
  }

  static RegExp _prepRegex(String prep) {
    final guard = switch (prep) {
      'a' => r'(?!las\b|la\b|tu\b|su\b|traves\b|nombre\b)',
      'en' => r'(?!tu\b|la\s+cuenta\b|tus\b)',
      'de' => r'(?!tu\b|la\s+cuenta\b|credito\b|debito\b)',
      _ => '',
    };
    return RegExp('(?:^|\\s)$prep\\s+$guard(.+)',
        caseSensitive: false, dotAll: true);
  }

  static String clean(String fragment) {
    var s = fragment.trim().replaceFirst(_processorPrefix, '');
    final m = _cutAt.firstMatch(s);
    if (m != null) s = s.substring(0, m.start);
    s = s.replaceFirst(
        RegExp(r'^(?:el|la|los|las|comercio|establecimiento)\s+',
            caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'''^["'“”]+|["'“”]+$'''), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'[\s\-–]+$'), '');
    if (s.length > 48) s = s.substring(0, 48).trim();
    return s;
  }
}

/// Últimos dígitos de la tarjeta o cuenta usada.
class AccountHintExtractor {
  AccountHintExtractor._();

  static final List<RegExp> _patterns = [
    RegExp(r'\*\s?(\d{4})\b'),
    RegExp(r'terminad[ao]\s+en\s+(\d{4})\b', caseSensitive: false),
    RegExp(r'final\s+(\d{4})\b', caseSensitive: false),
    RegExp(r'tarjeta\s+(?:\w+\s+){0,2}(\d{4})\b', caseSensitive: false),
    RegExp(r'cuenta\s+(?:\w+\s+){0,2}\**(\d{4})\b', caseSensitive: false),
  ];

  static String? extract(String text) {
    for (final p in _patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }
}

/// Fecha y hora mencionadas en el mensaje; si faltan, usa la de la notificación.
class DateTimeExtractor {
  DateTimeExtractor._();

  static final RegExp _date = RegExp(r'(?<!\d)(\d{1,2})/(\d{1,2})/(\d{2,4})(?!\d)');
  static final RegExp _time = RegExp(
    r'(?<!\d)(\d{1,2}):(\d{2})(?::\d{2})?\s*(a\.?\s?m\.?|p\.?\s?m\.?)?',
    caseSensitive: false,
  );

  static DateTime extract(String text, {required DateTime fallback}) {
    int? year;
    int? month;
    int? day;
    final dm = _date.firstMatch(text);
    if (dm != null) {
      day = int.parse(dm.group(1)!);
      month = int.parse(dm.group(2)!);
      year = int.parse(dm.group(3)!);
      if (year < 100) year += 2000;
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        day = month = year = null;
      }
    }

    int? hour;
    int? minute;
    final tm = _time.firstMatch(text);
    if (tm != null) {
      hour = int.parse(tm.group(1)!);
      minute = int.parse(tm.group(2)!);
      final ampm = tm.group(3)?.toLowerCase();
      if (ampm != null) {
        if (ampm.startsWith('p') && hour < 12) hour += 12;
        if (ampm.startsWith('a') && hour == 12) hour = 0;
      }
      if (hour > 23 || minute > 59) hour = minute = null;
    }

    DateTime candidate;
    if (day != null && hour != null) {
      candidate = DateTime(year!, month!, day, hour, minute!);
    } else if (day != null) {
      candidate =
          DateTime(year!, month!, day, fallback.hour, fallback.minute);
    } else if (hour != null) {
      candidate = DateTime(
          fallback.year, fallback.month, fallback.day, hour, minute!);
      if (candidate.isAfter(fallback.add(const Duration(hours: 2)))) {
        candidate = candidate.subtract(const Duration(days: 1));
      }
    } else {
      return fallback;
    }

    // Protección contra fechas absurdas (números que no eran fechas).
    if (candidate.isAfter(fallback.add(const Duration(days: 1))) ||
        candidate.isBefore(fallback.subtract(const Duration(days: 400)))) {
      return fallback;
    }
    return candidate;
  }
}
