import Cocoa
import FlutterMacOS
import multi_window_native
import window_manager

#if arch(x86_64)
// Impeller garbles text on some Intel Macs, so the x86_64 slice runs Skia. Info.plist
// is shared with the arm64 slice, and the engine reads FLTEnableImpeller from it
// through this lookup for every engine, including the overlay's. Remove once
// Flutter's opt-out goes away or a release fixes Impeller on Intel.
private extension Bundle {
  static let useSkia: Void = {
    guard
      let original = class_getInstanceMethod(
        Bundle.self, #selector(object(forInfoDictionaryKey:))),
      let replacement = class_getInstanceMethod(
        Bundle.self, #selector(skiaObject(forInfoDictionaryKey:)))
    else { return }
    method_exchangeImplementations(original, replacement)
  }()

  @objc func skiaObject(forInfoDictionaryKey key: String) -> Any? {
    if key == "FLTEnableImpeller" {
      return NSNumber(value: false)
    }
    return skiaObject(forInfoDictionaryKey: key)
  }
}
#endif

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    #if arch(x86_64)
    _ = Bundle.useSkia
    #endif

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    MultiWindowNativePlugin.onEngineCreatedCallback = { engine in
      // Re-register every plugin on each new sub-window engine so the
      // overlay window has access to window_manager, etc.
      //
      // The vendored multi_window_native plugin
      // (packages/multi_window_native) handles `.screenSaver` window
      // level + `.fullScreenAuxiliary` collection behaviour itself at
      // sub-window creation time, so no further window-level work is
      // needed here.
      RegisterGeneratedPlugins(registry: engine)
    }

    super.awakeFromNib()
  }
}
