import Flutter
import UIKit
import ReplayKit

// IMPORTANT: The App Group identifier below MUST be created in the Apple Developer portal
// (Certificates, Identifiers & Profiles → App Groups) and enabled on BOTH the Runner target
// AND the ScreenRecordBroadcast extension target in Signing & Capabilities.
//
// App bundle ID:        de.jonasbark.swiftcontrol.darwin
// App Group (derived):  group.de.jonasbark.swiftcontrol.darwin
// Extension bundle ID:  de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast

public class ScreenRecorderPlugin: NSObject, FlutterPlugin {
  // Derived from the app bundle id: group.<APP_BUNDLE_ID>
  static let appGroup = "group.de.jonasbark.swiftcontrol.darwin"

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
      presentBroadcastPicker()
      // Record intent in shared defaults; the extension reads it when it starts.
      sharedDefaults()?.set(true, forKey: "recordingRequested")
      result(true)
    case "stop":
      // Clear intent and signal the extension to finish via Darwin notification.
      sharedDefaults()?.set(false, forKey: "recordingRequested")
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
