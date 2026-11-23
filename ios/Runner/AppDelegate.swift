import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var mediaBridge: AniviewMediaBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AniviewMediaBridge") {
      let channel = FlutterMethodChannel(
        name: "app.aniview/media",
        binaryMessenger: registrar.messenger()
      )
      let bridge = AniviewMediaBridge()
      mediaBridge = bridge
      channel.setMethodCallHandler { [weak bridge] call, result in
        DispatchQueue.main.async {
          bridge?.handle(call, result: result)
        }
      }
    }
  }
}

private enum PickerKind {
  case video
  case attachment
  case backupRead
  case backupExport
}

private final class AniviewMediaBridge: NSObject, UIDocumentPickerDelegate {
  private static let maxAttachmentBytes = 10 * 1024 * 1024
  private var pendingResult: FlutterResult?
  private var pendingKind: PickerKind?
  private var pendingExportTempUrl: URL?
  private var originalBrightness: CGFloat?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickVideo":
      presentOpenPicker(kind: .video, result: result)
    case "pickAttachment":
      presentOpenPicker(kind: .attachment, result: result)
    case "readAttachment":
      readAttachment(uriString: call.arguments as? String, result: result)
    case "createBackup":
      createBackup(args: call.arguments as? [String: Any], result: result)
    case "readBackup":
      presentOpenPicker(kind: .backupRead, result: result)
    case "availableBytes":
      result(availableDiskBytes())
    case "getWindowBrightness":
      result(Double(currentScreen()?.brightness ?? -1))
    case "setWindowBrightness":
      setWindowBrightness(call.arguments, result: result)
    case "supportsPip", "enterPip":
      result(false)
    case "openBangumi":
      openBangumi(uriString: call.arguments as? String, result: result)
    case "setFullscreen":
      setFullscreen(full: (call.arguments as? Bool) ?? false, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }

  private func currentScreen() -> UIScreen? {
    activeWindowScene()?.screen ?? UIScreen.main
  }

  private func topViewController() -> UIViewController? {
    guard let scene = activeWindowScene() else { return nil }
    let window = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
    var current = window?.rootViewController
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  private func presentOpenPicker(kind: PickerKind, result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_busy", message: "A document picker is already active.", details: nil))
      return
    }
    guard let presenter = topViewController() else {
      result(FlutterError(code: "picker_unavailable", message: "Unable to find active iOS presenter.", details: nil))
      return
    }
    let types: [UTType]
    switch kind {
    case .video:
      types = [.movie, .audiovisualContent, .data, .item]
    case .attachment, .backupRead:
      types = [.json, .plainText, .xml, .data, .item]
    case .backupExport:
      types = [.json]
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.modalPresentationStyle = .formSheet
    pendingResult = result
    pendingKind = kind
    presenter.present(picker, animated: true)
  }

  private func createBackup(args: [String: Any]?, result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_busy", message: "A document picker is already active.", details: nil))
      return
    }
    guard let content = args?["content"] as? String else {
      result(FlutterError(code: "backup_invalid", message: "Backup payload missing.", details: nil))
      return
    }
    let rawName = (args?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let filename = (rawName?.isEmpty == false ? rawName! : "aniview-backup.json")
    let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
      try Data(content.utf8).write(to: tempUrl, options: .atomic)
    } catch {
      result(FlutterError(code: "backup_failed", message: error.localizedDescription, details: nil))
      return
    }
    guard let presenter = topViewController() else {
      try? FileManager.default.removeItem(at: tempUrl)
      result(FlutterError(code: "picker_unavailable", message: "Unable to find active iOS presenter.", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forExporting: [tempUrl], asCopy: true)
    picker.delegate = self
    picker.modalPresentationStyle = .formSheet
    pendingResult = result
    pendingKind = .backupExport
    pendingExportTempUrl = tempUrl
    presenter.present(picker, animated: true)
  }

  private func readAttachment(uriString: String?, result: @escaping FlutterResult) {
    guard let uriString, let url = URL(string: uriString), url.isFileURL else {
      result(FlutterError(code: "invalid_uri", message: "Unsupported file URI.", details: nil))
      return
    }
    do {
      let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
      if let size = (attrs[.size] as? NSNumber)?.int64Value, size > Self.maxAttachmentBytes {
        result(FlutterError(code: "attachment_too_large", message: "Attachment exceeds 10 MB.", details: nil))
        return
      }
      let data = try Data(contentsOf: url)
      if data.count > Self.maxAttachmentBytes {
        result(FlutterError(code: "attachment_too_large", message: "Attachment exceeds 10 MB.", details: nil))
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    } catch {
      result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func persistPickedVideo(from sourceUrl: URL) throws -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    let dir = docs.appendingPathComponent("AniViewMedia", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dest = dir.appendingPathComponent("\(UUID().uuidString)-\(sourceUrl.lastPathComponent)")
    if FileManager.default.fileExists(atPath: dest.path) {
      try FileManager.default.removeItem(at: dest)
    }
    try FileManager.default.moveItem(at: sourceUrl, to: dest)
    return dest
  }

  private func availableDiskBytes() -> Int64? {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory())
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage
  }

  private func setWindowBrightness(_ argument: Any?, result: @escaping FlutterResult) {
    guard let screen = currentScreen() else {
      result(nil)
      return
    }
    if let numeric = argument as? NSNumber {
      let value = CGFloat(numeric.doubleValue)
      if value < 0 {
        if let saved = originalBrightness {
          screen.brightness = saved
          originalBrightness = nil
        }
      } else {
        if originalBrightness == nil {
          originalBrightness = screen.brightness
        }
        screen.brightness = min(max(value, 0.01), 1.0)
      }
    } else if let saved = originalBrightness {
      screen.brightness = saved
      originalBrightness = nil
    }
    result(nil)
  }

  private func openBangumi(uriString: String?, result: @escaping FlutterResult) {
    guard
      let uriString,
      let url = URL(string: uriString),
      url.scheme == "https",
      let host = url.host,
      host == "bgm.tv" || host == "next.bgm.tv"
    else {
      result(FlutterError(code: "invalid_address", message: "Invalid Bangumi URL", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      if opened {
        result(nil)
      } else {
        result(FlutterError(code: "browser_unavailable", message: "Unable to open Safari", details: nil))
      }
    }
  }

  private func setFullscreen(full: Bool, result: @escaping FlutterResult) {
    if UIDevice.current.userInterfaceIdiom == .phone, #available(iOS 16.0, *), let scene = activeWindowScene() {
      let mask: UIInterfaceOrientationMask = full ? .landscape : .portrait
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
    result(nil)
  }

  private func clearPendingExport() {
    if let temp = pendingExportTempUrl {
      try? FileManager.default.removeItem(at: temp)
      pendingExportTempUrl = nil
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult, let kind = pendingKind else { return }
    pendingResult = nil
    pendingKind = nil

    guard let url = urls.first else {
      clearPendingExport()
      result(kind == .backupExport ? false : nil)
      return
    }

    switch kind {
    case .video:
      do {
        let localUrl = try persistPickedVideo(from: url)
        result(["uri": localUrl.absoluteString, "name": url.lastPathComponent])
      } catch {
        result(["uri": url.absoluteString, "name": url.lastPathComponent])
      }
    case .attachment:
      result(["uri": url.absoluteString, "name": url.lastPathComponent])
    case .backupRead:
      do {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = (attrs[.size] as? NSNumber)?.int64Value, size > Self.maxAttachmentBytes {
          result(FlutterError(code: "backup_too_large", message: "Backup exceeds 10 MB.", details: nil))
          return
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        result(text)
      } catch {
        result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
      }
    case .backupExport:
      clearPendingExport()
      result(true)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let result = pendingResult, let kind = pendingKind else { return }
    pendingResult = nil
    pendingKind = nil
    clearPendingExport()
    result(kind == .backupExport ? false : nil)
  }
}
