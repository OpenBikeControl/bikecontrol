import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)

      // Promote sub-windows (currently only the trainer overlay) so they sit
      // above fullscreened trainer apps (Zwift / MyWhoosh / Rouvy on their
      // own Space). `.fullScreenAuxiliary` lets the window participate in
      // any Space's fullscreen layer; a `.statusBar`-level keeps it above
      // the fullscreen app's own content. Dispatch async because
      // `controller.view.window` is nil until the view is hosted.
      DispatchQueue.main.async {
        guard let window = controller.view.window else { return }
        window.level = .statusBar
        window.collectionBehavior = [
          .canJoinAllSpaces,
          .fullScreenAuxiliary,
          .stationary,
          .ignoresCycle,
        ]
      }
    }

    super.awakeFromNib()
  }
}
