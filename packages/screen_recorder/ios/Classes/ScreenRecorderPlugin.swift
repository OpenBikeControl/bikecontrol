import Flutter
import UIKit
import ReplayKit

// IMPORTANT: This reuses the app's EXISTING App Group "group.de.jonasbark.swiftcontrol.overlay"
// (already configured on the Runner target and in the portal). It must ALSO be enabled on the
// ScreenRecordBroadcast extension target (Signing & Capabilities → App Groups → check the
// existing group). Without it the extension can't resolve its shared container, and the
// broadcast can be neither stopped nor saved.
//
// App bundle ID:        de.jonasbark.swiftcontrol.darwin
// Shared App Group:     group.de.jonasbark.swiftcontrol.overlay
// Extension bundle ID:  de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast

public class ScreenRecorderPlugin: NSObject, FlutterPlugin {
  // Reuse the app's existing shared App Group (already on the Runner target).
  static let appGroup = "group.de.jonasbark.swiftcontrol.overlay"

  // Darwin notification name used to signal the extension to stop.
  // Must match the string used in SampleHandler.swift.
  static let stopNotificationName = "de.jonasbark.swiftcontrol.darwin.stopBroadcast"

  // The extension's bundle id. Must match the Target's Bundle Identifier set in Xcode.
  static let extensionBundleId = "de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screen_recorder", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ScreenRecorderPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "hasPermission", "requestPermission":
      // Broadcast is user-initiated via system sheet; no separate permission required.
      result(true)
    case "start":
      // Clear any stale stop flag so a fresh recording isn't immediately stopped.
      clearStopFlag()
      sharedDefaults()?.removeObject(forKey: "lastRecordingPath")
      presentBroadcastPicker()
      sharedDefaults()?.set(true, forKey: "recordingRequested")
      result(true)
    case "stop":
      sharedDefaults()?.set(false, forKey: "recordingRequested")
      // Primary stop: drop a flag file in the shared App Group container that the
      // extension polls on every frame (reliable cross-process). Backup: a Darwin
      // notification (immediate, but delivery to broadcast extensions is flaky).
      writeStopFlag()
      NSLog("ScreenRecorderPlugin: posting stop notification %@", ScreenRecorderPlugin.stopNotificationName)
      CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(ScreenRecorderPlugin.stopNotificationName as CFString),
        nil, nil, true)
      // The extension writes the final output path into shared defaults when it finishes.
      let path = sharedDefaults()?.string(forKey: "lastRecordingPath")
      result(path)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func sharedDefaults() -> UserDefaults? {
    UserDefaults(suiteName: ScreenRecorderPlugin.appGroup)
  }

  private func appGroupContainer() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenRecorderPlugin.appGroup)
  }

  private func stopFlagURL() -> URL? {
    appGroupContainer()?.appendingPathComponent("screen_recorder_stop")
  }

  private func clearStopFlag() {
    if let url = stopFlagURL() { try? FileManager.default.removeItem(at: url) }
  }

  private func writeStopFlag() {
    guard let container = appGroupContainer(), let stop = stopFlagURL() else {
      NSLog("ScreenRecorderPlugin: WARNING no App Group container in app — is %@ enabled on the Runner target?",
            ScreenRecorderPlugin.appGroup)
      return
    }
    FileManager.default.createFile(atPath: stop.path, contents: Data())
    // Heartbeat: the extension writes this file in broadcastStarted. If it's MISSING,
    // the extension isn't sharing the App Group (capability not enabled on the extension
    // target) or isn't running our SampleHandler — so it can never be stopped/saved.
    let alive = FileManager.default.fileExists(atPath: container.appendingPathComponent("screen_recorder_active").path)
    NSLog("ScreenRecorderPlugin: stop flag written; extension heartbeat = %@",
          alive ? "ALIVE" : "MISSING (App Group not shared with extension, or extension not running our code)")
  }

  private func presentBroadcastPicker() {
    DispatchQueue.main.async {
      let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
      // Preselect our extension so the user's tap targets it immediately.
      picker.preferredExtension = ScreenRecorderPlugin.extensionBundleId
      picker.showsMicrophoneButton = false
      // Add to the key window so the picker can present its sheet.
      if let windowScene = UIApplication.shared.connectedScenes
          .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
         let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
        window.addSubview(picker)
      }
      // Programmatically tap the picker button — the user still sees and confirms the sheet.
      for subview in picker.subviews {
        if let button = subview as? UIButton {
          button.sendActions(for: .touchUpInside)
        }
      }
    }
  }
}
