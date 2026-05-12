import Cocoa
import FlutterMacOS
import multi_window_native

@main
class AppDelegate: FlutterAppDelegate  {

  override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)

        //plugin changes
        MultiWindowNativePlugin.onEngineCreatedCallback = { engine in
            print("📌 New secondary engine created: \(engine)")
            // Register all plugins for the new engine
            RegisterGeneratedPlugins(registry: engine)
        }
    }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  // override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
  //   return true
  // }
}
