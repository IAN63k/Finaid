import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../core/external_launch.dart';

class PickedDocument {
  const PickedDocument({required this.bytes, this.name});

  final Uint8List bytes;
  final String? name;
}

class DocumentStorageException implements Exception {
  const DocumentStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Guardar y abrir archivos con el selector del sistema (ver DocumentChannel.kt).
/// En iOS se implementará con UIDocumentPicker sobre el mismo canal.
class DocumentStorage {
  const DocumentStorage([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'co.finaid/documents';

  final MethodChannel _channel;

  /// Devuelve la URI del archivo creado, o `null` si el usuario canceló.
  Future<String?> save({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    ExternalLaunch.notify();
    try {
      return await _channel.invokeMethod<String>('saveDocument', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      throw DocumentStorageException(e.message ?? 'No se pudo guardar el archivo');
    } on MissingPluginException {
      throw const DocumentStorageException(
          'Guardar archivos no está disponible en esta plataforma');
    }
  }

  /// Devuelve el archivo elegido, o `null` si el usuario canceló.
  Future<PickedDocument?> open({List<String> mimeTypes = const []}) async {
    ExternalLaunch.notify();
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>(
          'openDocument', {'mimeTypes': mimeTypes});
      if (m == null) return null;
      final bytes = m['bytes'];
      return PickedDocument(
        bytes: bytes is Uint8List
            ? bytes
            : Uint8List.fromList(List<int>.from(bytes as List)),
        name: m['name'] as String?,
      );
    } on PlatformException catch (e) {
      throw DocumentStorageException(e.message ?? 'No se pudo abrir el archivo');
    } on MissingPluginException {
      throw const DocumentStorageException(
          'Abrir archivos no está disponible en esta plataforma');
    }
  }
}
