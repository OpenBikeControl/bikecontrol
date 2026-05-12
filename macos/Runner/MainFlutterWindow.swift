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
      RegisterGeneratedPlugins(registry: engine)


      // Promote sub-windows (currently only the trainer overlay) so they sit
      // above fullscreened trainer apps (Zwift / MyWhoosh / Rouvy on their
      // own Space). `.fullScreenAuxiliary` lets the window participate in
      // any Space's fullscreen layer; a `.statusBar`-level keeps it above
      // the fullscreen app's content. Dispatched async because the engine's
      // view isn't yet hosted in an NSWindow at this callback site.
      DispatchQueue.main.async {
        for window in NSApp.windows {
          guard window != self,
                let vc = window.contentViewController as? FlutterViewController,
                vc.engine == engine else { continue }
          window.level = .statusBar
          window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
          ]
          break
        }
      }
    }

    super.awakeFromNib()
  }
}
