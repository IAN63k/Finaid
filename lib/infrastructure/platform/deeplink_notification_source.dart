import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/raw_notification.dart';
import '../../domain/ports/notification_source.dart';

/// Fuente por deep link: `finaid://ingest?app=<bundle>&title=<t>&text=<cuerpo>&ts=<epoch ms>`.
///
/// Es el camino previsto para iOS: una automatización de Atajos captura la
/// notificación bancaria y abre esa URL. En Android también funciona (sirve
/// para pruebas con `adb shell am start -a android.intent.action.VIEW -d ...`).
class DeepLinkNotificationSource implements NotificationSource {
  DeepLinkNotificationSource({AppLinks? appLinks, Uuid? uuid})
      : _appLinks = appLinks ?? AppLinks(),
        _uuid = uuid ?? const Uuid();

  static const String scheme = 'finaid';
  static const String host = 'ingest';

  final AppLinks _appLinks;
  final Uuid _uuid;
  final StreamController<RawNotification> _controller =
      StreamController.broadcast();
  StreamSubscription<Uri>? _subscription;
  bool _initialConsumed = false;

  @override
  String get id => 'deeplink';

  @override
  Future<bool> isAvailable() async => Platform.isAndroid || Platform.isIOS;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Stream<RawNotification> get stream => _controller.stream;

  @override
  Future<void> start() async {
    _subscription ??= _appLinks.uriLinkStream.listen((uri) {
      final n = parseUri(uri);
      if (n != null) _controller.add(n);
    }, onError: (Object _) {});
  }

  @override
  Future<List<RawNotification>> drainPending() async {
    if (_initialConsumed) return const [];
    _initialConsumed = true;
    try {
      final initial = await _appLinks.getInitialLink();
      final n = initial == null ? null : parseUri(initial);
      return n == null ? const [] : [n];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  RawNotification? parseUri(Uri uri) {
    if (uri.scheme != scheme || uri.host != host) return null;
    final q = uri.queryParameters;
    final text = (q['text'] ?? '').trim();
    if (text.isEmpty) return null;
    final app = (q['app'] ?? '').trim();
    final ts = int.tryParse(q['ts'] ?? '');
    final postedAt =
        ts == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ts);
    final channel = Platform.isIOS
        ? NotificationChannel.iosShortcut
        : NotificationChannel.manual;
    return RawNotification(
      id: _uuid.v4(),
      sourcePackage: app.isEmpty ? 'deeplink' : app,
      title: q['title'],
      text: text,
      postedAt: postedAt,
      channel: channel,
      dedupeKey: 'dl:${app}_${ts ?? ''}_${text.hashCode}',
    );
  }
}
