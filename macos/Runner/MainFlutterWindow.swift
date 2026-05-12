import Cocoa
import FlutterMacOS
import multi_window_native
import window_manager

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
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
