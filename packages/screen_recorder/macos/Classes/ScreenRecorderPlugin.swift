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
        let rec = ScreenCaptureRecorder()
        self.recorder = rec
        Task {
          do { try await rec.start(); result(true) }
          catch { NSLog("screen_recorder start error: \(error)"); result(false) }
        }
      } else { result(false) }
    case "stop":
      if #available(macOS 12.3, *), let rec = self.recorder as? ScreenCaptureRecorder {
        Task { let path = await rec.stop(); self.recorder = nil; result(path) }
      } else { result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
