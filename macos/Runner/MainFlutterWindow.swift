import Cocoa
import FlutterMacOS
import multi_window_native
import window_manager

class MainFlutterWindow: NSPanel {
  // NSPanel defaults `canBecomeMain` and `canBecomeKey` to false (it's designed
  // for utility palettes). multi_window_native's macOS plugin registers the
  // main app's messenger by looking up `NSApp.mainWindow` — which skips
  // anything that returns false here. Without the override, sub-windows can
  // never broadcast back to main.
  override var canBecomeMain: Bool { true }
  override var canBecomeKey: Bool { true }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // NSPanel can default to `.floating` depending on style mask, which
    // would sit above the trainer-overlay sub-window even after we elevate
    // it to `.statusBar`. Pin to `.normal` so the elevation actually wins.
    self.level = .normal

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
