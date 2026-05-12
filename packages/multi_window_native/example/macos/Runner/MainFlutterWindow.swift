import Cocoa
import FlutterMacOS
import multi_window_native

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Set callback for secondary windows
    //plugin changes
        MultiWindowNativePlugin.onEngineCreatedCallback = { engine in
            print("📌 New secondary engine created: \(engine)")
            // Register all plugins for the new engine
            RegisterGeneratedPlugins(registry: engine)
        }

    super.awakeFromNib()
  }
}
