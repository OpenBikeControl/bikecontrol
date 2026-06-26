import Cocoa
import FlutterMacOS
import CoreGraphics

public class ScreenRecorderPlugin: NSObject, FlutterPlugin {
  private var recorder: AnyObject?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screen_recorder", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(ScreenRecorderPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(macOS 12.3, *) { result(true) } else { result(false) }
    case "hasPermission":
      result(CGPreflightScreenCaptureAccess())
    case "requestPermission":
      result(CGRequestScreenCaptureAccess())
    case "start":
      if #available(macOS 12.3, *) {
        // Fix 6 (double-start leak): guard against starting a second recorder
        guard self.recorder == nil else { result(false); return }
        let rec = ScreenCaptureRecorder()
        self.recorder = rec
        Task {
          do {
            try await rec.start()
            // Fix 7 (main thread): call FlutterResult on the main thread
            DispatchQueue.main.async { result(true) }
          } catch {
            NSLog("screen_recorder start error: \(error)")
            // Reset so a failed start doesn't leave `recorder` non-nil, which
            // would trip the `guard recorder == nil` on every later start
            // (recording stays dead until app relaunch, since only stop() nils it).
            DispatchQueue.main.async {
              self.recorder = nil
              result(false)
            }
          }
        }
      } else { result(false) }
    case "stop":
      if #available(macOS 12.3, *), let rec = self.recorder as? ScreenCaptureRecorder {
        Task {
          let path = await rec.stop()
          self.recorder = nil
          // Fix 7 (main thread): call FlutterResult on the main thread
          DispatchQueue.main.async { result(path) }
        }
      } else { result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
