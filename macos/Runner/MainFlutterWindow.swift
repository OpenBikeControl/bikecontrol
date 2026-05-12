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

    MultiWindowNativePlugin.onEngineCreatedCallback = { [weak self] engine in
      // Re-register every plugin on each new sub-window engine so the
      // overlay window has access to window_manager, etc.
      RegisterGeneratedPlugins(registry: engine)

      // Promote sub-windows (currently only the trainer overlay) so they sit
      // above fullscreened trainer apps (Zwift / MyWhoosh / Rouvy on their
      // own Space). `.fullScreenAuxiliary` lets the window participate in
      // any Space's fullscreen layer; a `.statusBar`-level keeps it above
      // the fullscreen app's content.
      //
      // The plugin fires this callback BEFORE it creates the NSWindow and
      // sets its contentViewController (see MultiWindowNativePlugin.swift
      // ~line 145 vs 150). A single asyncAfter(0) used to race the window's
      // own setup and silently miss it. Retry several times with a short
      // delay until we find the new sub-window hosting `engine`.
      func tryElevate(attempts: Int) {
        guard let self = self else { return }
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
          // Setting `.level` alone doesn't re-stack the window within its
          // new level group. Without `orderFront`, the sub-window stays
          // visually behind the main panel until something else forces a
          // restack (minimising and restoring main, for instance).
          window.orderFront(nil)
          NSLog("[trainer-overlay] sub-window elevated to .statusBar")
          return
        }
        if attempts < 30 {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tryElevate(attempts: attempts + 1)
          }
        } else {
          NSLog("[trainer-overlay] sub-window not found after 30 attempts")
        }
      }
      DispatchQueue.main.async {
        tryElevate(attempts: 0)
      }
    }

    super.awakeFromNib()
  }
}
