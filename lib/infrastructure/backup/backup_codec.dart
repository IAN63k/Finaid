import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/backup/backup_payload.dart';

enum BackupError {
  /// El archivo no es un respaldo de Finaid.
  notABackup,

  /// Creado por una versión más nueva de Finaid.
  unsupportedVersion,

  /// Está cifrado y no se dio contraseña.
  passwordRequired,

  /// Contraseña incorrecta o archivo alterado.
  wrongPassword,

  /// JSON dañado o incompleto.
  corrupted,
}

class BackupException implements Exception {
  const BackupException(this.error, [this.detail]);

  final BackupError error;
  final String? detail;

  @override
  String toString() => 'BackupException($error${detail == null ? '' : ': $detail'})';
}

/// Datos visibles sin descifrar.
class BackupInfo {
  const BackupInfo({
    required this.encrypted,
    required this.createdAt,
    required this.appVersion,
  });

  final bool encrypted;
  final DateTime? createdAt;
  final String appVersion;
}

/// Sobre del archivo de respaldo (JSON):
///
/// ```json
/// {"format": "finaid-backup", "version": 1, "created_at": "...", "app_version": "...",
///  "encrypted": true,
///  "kdf": {"name": "pbkdf2-hmac-sha256", "iterations": 100000, "salt": "<b64>"},
///  "cipher": {"name": "aes-256-gcm"},
///  "data": "<b64 nonce(12) + texto cifrado + mac(16)>"}
/// ```
///
/// Sin contraseña, `encrypted` es `false` y los datos van en claro en `payload`.
class BackupCodec {
  BackupCodec({this.iterations = defaultIterations, Random? random})
      : _random = random ?? Random.secure();

  static const String format = 'finaid-backup';
  static const int envelopeVersion = 1;
  static const int defaultIterations = 100000;

  final int iterations;
  final Random _random;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<Uint8List> encode(BackupPayload payload, {String? password}) async {
    final clear = utf8.encode(jsonEncode(payload.toJson()));
    final envelope = <String, Object?>{
      'format': format,
      'version': envelopeVersion,
      'created_at': payload.createdAt.toIso8601String(),
      'app_version': payload.appVersion,
    };

    if (password == null || password.isEmpty) {
      envelope['encrypted'] = false;
      envelope['payload'] = payload.toJson();
    } else {
      final salt = _bytes(16);
      final key = await _deriveKey(password, salt, iterations);
      final box = await _cipher.encrypt(clear,
          secretKey: key, nonce: _cipher.newNonce());
      envelope['encrypted'] = true;
      envelope['kdf'] = {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      };
      envelope['cipher'] = {'name': 'aes-256-gcm'};
      envelope['data'] = base64Encode(box.concatenation());
    }
    return Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope)));
  }

  BackupInfo inspect(Uint8List bytes) {
    final env = _envelope(bytes);
    return BackupInfo(
      encrypted: env['encrypted'] == true,
      createdAt: DateTime.tryParse('${env['created_at']}'),
      appVersion: '${env['app_version'] ?? ''}',
    );
  }

  Future<BackupPayload> decode(Uint8List bytes, {String? password}) async {
    final env = _envelope(bytes);
    try {
      if (env['encrypted'] != true) {
        return BackupPayload.fromJson(
            Map<String, Object?>.from(env['payload'] as Map));
      }
      if (password == null || password.isEmpty) {
        throw const BackupException(BackupError.passwordRequired);
      }
      final kdf = Map<String, Object?>.from(env['kdf'] as Map);
      final salt = base64Decode(kdf['salt'] as String);
      final rounds = (kdf['iterations'] as num).toInt();
      final key = await _deriveKey(password, salt, rounds);
      final box = SecretBox.fromConcatenation(
        base64Decode(env['data'] as String),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      final List<int> clear;
      try {
        clear = await _cipher.decrypt(box, secretKey: key);
      } on SecretBoxAuthenticationError {
        throw const BackupException(BackupError.wrongPassword);
      }
      return BackupPayload.fromJson(
          Map<String, Object?>.from(jsonDecode(utf8.decode(clear)) as Map));
    } on BackupException {
      rethrow;
    } on FormatException catch (e) {
      if (e.message.startsWith('Versión de respaldo no soportada')) {
        throw BackupException(BackupError.unsupportedVersion, e.message);
      }
      throw BackupException(BackupError.corrupted, e.message);
    } catch (e) {
      throw BackupException(BackupError.corrupted, '$e');
    }
  }

  Map<String, Object?> _envelope(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } catch (_) {
      throw const BackupException(BackupError.notABackup);
    }
    if (decoded is! Map || decoded['format'] != format) {
      throw const BackupException(BackupError.notABackup);
    }
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > envelopeVersion) {
      throw BackupException(
          BackupError.unsupportedVersion, 'Sobre versión $version');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt, int rounds) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  List<int> _bytes(int n) => List<int>.generate(n, (_) => _random.nextInt(256));
}

// -----------------------------------------------------------------------------
// Ejecución en segundo plano
// -----------------------------------------------------------------------------
//
// PBKDF2 tarda (a propósito), así que el cifrado corre en otro isolate. Estas
// funciones son de nivel superior a propósito: un closure creado dentro de un
// método de un widget o de un State captura `this` (y con él todo el árbol de
// widgets), y Dart no puede enviarlo a otro isolate ("object is unsendable").
// Aquí el closure solo captura los argumentos, que son datos simples.

/// Cifra (o serializa, sin contraseña) el respaldo fuera del hilo de la interfaz.
Future<Uint8List> encodeBackupInBackground(
  BackupPayload payload, {
  String? password,
  int iterations = BackupCodec.defaultIterations,
}) =>
    Isolate.run(() =>
        BackupCodec(iterations: iterations).encode(payload, password: password));

/// Descifra el respaldo fuera del hilo de la interfaz. Propaga [BackupException].
Future<BackupPayload> decodeBackupInBackground(
  Uint8List bytes, {
  String? password,
}) =>
    Isolate.run(() => BackupCodec().decode(bytes, password: password));
