import Flutter
import LocalAuthentication
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// Puente nativo de Finaid en iOS. Implementa los mismos canales y métodos que
/// el lado Android, para que el código Dart no cambie:
///
///  - `co.finaid/auth`: Face ID, Touch ID o código del iPhone (bloqueo de la app).
///  - `co.finaid/documents`: guardar y abrir archivos (respaldo, CSV).
///  - `co.finaid/notifications`: avisos locales (capturas, alertas de presupuesto,
///    recordatorios de pagos), permiso de avisos, datos del equipo y abrir Atajos.
///
/// iOS no permite leer notificaciones de otras apps: la captura llega por Atajos
/// con el enlace `finaid://ingest`, que maneja `app_links` en Dart.
public class FinaidIosPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UNUserNotificationCenterDelegate
{
  private var pendingDocument: FlutterResult?
  private var pendingMode: String?

  private static let maxOpenBytes = 50 * 1024 * 1024
  private static let reminderPrefix = "reminder-"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FinaidIosPlugin()
    let messenger = registrar.messenger()
    FlutterMethodChannel(name: "co.finaid/auth", binaryMessenger: messenger)
      .setMethodCallHandler(instance.handleAuth)
    FlutterMethodChannel(name: "co.finaid/documents", binaryMessenger: messenger)
      .setMethodCallHandler(instance.handleDocuments)
    FlutterMethodChannel(name: "co.finaid/notifications", binaryMessenger: messenger)
      .setMethodCallHandler(instance.handleNotifications)
    // Mostrar también los avisos con la app abierta (recordatorios).
    UNUserNotificationCenter.current().delegate = instance
    registrar.publish(instance)
  }

  // MARK: - Autenticación

  private func handleAuth(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      let available = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
      let biometric = LAContext().canEvaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics, error: nil)
      result(["available": available, "biometric": biometric])

    case "authenticate":
      let args = call.arguments as? [String: Any]
      let reason =
        (args?["subtitle"] as? String) ?? (args?["title"] as? String) ?? "Desbloquear Finaid"
      let context = LAContext()
      context.localizedCancelTitle = "Cancelar"
      var error: NSError?
      guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        result("unavailable")
        return
      }
      context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
        success, error in
        DispatchQueue.main.async {
          if success {
            result("success")
            return
          }
          switch (error as? LAError)?.code {
          case .userCancel?, .systemCancel?, .appCancel?, .userFallback?:
            result("cancelled")
          case .biometryLockout?:
            result("lockout")
          case .passcodeNotSet?:
            result("unavailable")
          default:
            result("error")
          }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Archivos

  private func handleDocuments(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingDocument == nil else {
      result(FlutterError(code: "busy", message: "Ya hay un selector de archivos abierto", details: nil))
      return
    }
    guard let presenter = FinaidIosPlugin.topViewController() else {
      result(FlutterError(code: "no_picker", message: "No hay una pantalla para mostrar el selector", details: nil))
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "saveDocument":
      let name = (args["fileName"] as? String) ?? "finaid"
      let data = (args["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      do {
        try data.write(to: url, options: .atomic)
      } catch {
        result(FlutterError(code: "io_error", message: error.localizedDescription, details: nil))
        return
      }
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      } else {
        picker = UIDocumentPickerViewController(url: url, in: .exportToService)
      }
      present(picker, mode: "save", result: result, from: presenter)

    case "openDocument":
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
      } else {
        picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
      }
      present(picker, mode: "open", result: result, from: presenter)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func present(
    _ picker: UIDocumentPickerViewController, mode: String, result: @escaping FlutterResult,
    from presenter: UIViewController
  ) {
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pendingDocument = result
    pendingMode = mode
    presenter.present(picker, animated: true)
  }

  public func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    let result = pendingDocument
    let mode = pendingMode
    pendingDocument = nil
    pendingMode = nil
    guard let result = result else { return }

    if mode == "save" {
      result(urls.first?.absoluteString ?? "saved")
      return
    }
    guard let url = urls.first else {
      result(nil)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try Data(contentsOf: url)
      if data.count > FinaidIosPlugin.maxOpenBytes {
        result(FlutterError(code: "io_error", message: "El archivo es demasiado grande", details: nil))
        return
      }
      result(["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: data)])
    } catch {
      result(FlutterError(code: "io_error", message: error.localizedDescription, details: nil))
    }
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingDocument
    pendingDocument = nil
    pendingMode = nil
    result?(nil)
  }

  // MARK: - Avisos locales

  private func handleNotifications(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "hasPostNotificationPermission":
      center.getNotificationSettings { settings in
        let ok =
          settings.authorizationStatus == .authorized
          || settings.authorizationStatus == .provisional
        DispatchQueue.main.async { result(ok) }
      }

    case "requestPostNotificationPermission":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        DispatchQueue.main.async { result(nil) }
      }

    case "showCaptureNotification":
      let content = UNMutableNotificationContent()
      content.title = (args["title"] as? String) ?? "Finaid"
      content.body = (args["body"] as? String) ?? ""
      content.sound = .default
      content.threadIdentifier = (args["channel"] as? String) ?? "captures"
      let request = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(request) { _ in DispatchQueue.main.async { result(nil) } }

    case "scheduleReminders":
      let items = args["items"] as? [[String: Any]] ?? []
      center.getPendingNotificationRequests { pending in
        let old = pending.map { $0.identifier }
          .filter { $0.hasPrefix(FinaidIosPlugin.reminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        var scheduled = 0
        // iOS guarda como máximo 64 avisos pendientes por app.
        for item in items.prefix(50) {
          guard let id = (item["id"] as? NSNumber)?.intValue,
            let atMillis = (item["at"] as? NSNumber)?.doubleValue
          else { continue }
          let date = Date(timeIntervalSince1970: atMillis / 1000)
          if date <= Date() { continue }
          let content = UNMutableNotificationContent()
          content.title = (item["title"] as? String) ?? "Finaid"
          content.body = (item["body"] as? String) ?? ""
          content.sound = .default
          content.threadIdentifier = "reminders"
          let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
          let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
          center.add(
            UNNotificationRequest(
              identifier: "\(FinaidIosPlugin.reminderPrefix)\(id)", content: content,
              trigger: trigger))
          scheduled += 1
        }
        DispatchQueue.main.async { result(scheduled) }
      }

    case "deviceInfo":
      let version = UIDevice.current.systemVersion
      let major = Int(version.split(separator: ".").first ?? "0") ?? 0
      result([
        "manufacturer": "Apple",
        "model": FinaidIosPlugin.modelIdentifier(),
        "sdk": major,
        "release": version,
      ])

    case "openShortcuts":
      guard let url = URL(string: "shortcuts://") else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in result(ok) }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  // MARK: - Utilidades

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private static func modelIdentifier() -> String {
    var info = utsname()
    uname(&info)
    let mirror = Mirror(reflecting: info.machine)
    return mirror.children.reduce("") { id, element in
      guard let value = element.value as? Int8, value != 0 else { return id }
      return id + String(UnicodeScalar(UInt8(value)))
    }
  }
}
