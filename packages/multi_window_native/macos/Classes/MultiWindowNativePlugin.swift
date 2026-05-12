import Cocoa
import FlutterMacOS

typealias SecondaryWindowControllers = (
    window: NSWindow, flutterViewController: FlutterViewController
)

public class MultiWindowNativePlugin: NSObject, FlutterPlugin,  NSWindowDelegate{

    // Callback to register plugins for new engines
    public static var onEngineCreatedCallback: ((FlutterEngine) -> Void)?

    private static var messengers: [FlutterBinaryMessenger] = []
    private  var secondaryWindowControllers: [SecondaryWindowControllers] = []
    private  var mainWindow: NSWindow?
    private static let channelName = "com.coditas.multi_window_native/pluginChannel"
    
    // Track window titles for unique title generation
    private var registeredWindowTitles: Set<String> = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
        let instance = MultiWindowNativePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Add this engine's messenger to the broadcast list directly. The
        // upstream package only added it if `NSApp.mainWindow` happened to
        // be set when `register(with:)` fired — which, for the main engine,
        // is called from `awakeFromNib` *before* the window is shown and
        // promoted to mainWindow. That's why sub-window broadcasts silently
        // failed to reach Dart-main when the overlay was auto-opened early
        // in the app lifecycle (BLE reconnects fast on a paired trainer).
        // Doing the append here, using the registrar's own messenger, makes
        // it deterministic regardless of NSApp.mainWindow timing.
        if !messengers.contains(where: { $0 === registrar.messenger }) {
            messengers.append(registrar.messenger)
        }

        // Wire the main window as our NSWindowDelegate when it becomes
        // available so cleanup on app close still runs. This may be nil at
        // register time for the main engine; the sub-engine's later
        // register call will populate it once the main window is shown.
        if let mainFlutterWindow = NSApp.mainWindow,
           let _ = mainFlutterWindow.contentViewController as? FlutterViewController {
            instance.mainWindow = mainFlutterWindow
            mainFlutterWindow.delegate = instance
        }
    }

    
    // Handle method calls from Flutter (main window)
    public func handle(_ call: FlutterMethodCall,result: @escaping FlutterResult) {
        print("Inside handle")
        switch call.method {
        case "generateUniqueTitle":
            guard let baseTitle = call.arguments as? String else {
                result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                return
            }
            let uniqueTitle = generateUniqueTitle(baseTitle: baseTitle)
            result(uniqueTitle)
            return
        case "registerWindowTitle":
            guard let title = call.arguments as? String else {
                result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                return
            }
            registeredWindowTitles.insert(title)
            result(true)
            return
        case "unregisterWindowTitle":
            guard let title = call.arguments as? String else {
                result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                return
            }
            registeredWindowTitles.remove(title)
            result(true)
            return
        case "notifyUiReady":
            DispatchQueue.main.async {
            if let (window, _) = self.secondaryWindowControllers.last {
                window.makeKeyAndOrderFront(nil)
            }
                result(true)
            }
            return
        case "createWindow":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "ARG_ERROR", message: "Expected dictionary", details: nil))
                return
            }

            // Convert dictionary values to list of strings
            let argsList: [String] = [
                args["routeName"] as? String ?? "",
                args["theme"] as? String ?? "",
                args["argsJson"] as? String ?? ""
            ]
            createNewWindow(with: argsList) { success in result(success) }
            return
        case "closeWindow":
            // The Dart side calls `closeWindow(isMainWindow: false, windowId: ...)`
            // to dismiss a specific secondary window. Two things to get right:
            //
            // 1. The package historically ignored those args and slammed
            //    `NSApp.mainWindow` instead, which either terminated the app
            //    or no-op'd silently depending on whether `NSApp.mainWindow`
            //    was set yet — so the overlay never actually closed from
            //    the main side.
            //
            // 2. We must NOT call `self.closeWindow(window)` directly here:
            //    that calls `window.close()`, which synchronously fires the
            //    `windowWillClose` delegate, which calls back into
            //    `self.closeWindow(window)` — and then the outer call's
            //    `secondaryWindowControllers.remove(at: index)` blows up on
            //    a now-stale index. Just call `window.close()` and let the
            //    delegate path do the one-pass cleanup.
            if let args = call.arguments as? [String: Any],
               let isMain = args["isMainWindow"] as? Bool, !isMain {
                // We don't track windowId per secondary, but for our usage
                // there's at most one secondary at a time. Close them all.
                let windows = self.secondaryWindowControllers.map { $0.window }
                for window in windows {
                    window.close()
                }
            } else if let mainWindow = NSApp.mainWindow {
                self.closeWindow(mainWindow)
            }
            result(true)
            return
        case "getMessengerCount":
            result(Self.messengers.count)
            return
        default:
            // Broadcast other calls to all windows
            broadcastToAllWindows(method: call.method, arguments: call.arguments)
            result(true)
    }
    }
    
    // Generate unique window title
    private func generateUniqueTitle(baseTitle: String) -> String {
        var suffix = 1
        var newTitle = "\(baseTitle) \(suffix)"
        
        // Check if title already exists and increment suffix
        while registeredWindowTitles.contains(newTitle) {
            suffix += 1
            newTitle = "\(baseTitle) \(suffix)"
        }
        
        return newTitle
    }
    
    
    // Setup channel for newly created window (especially for secondary)
    private func setupChannelHandler(for messenger: FlutterBinaryMessenger, controller: FlutterViewController) {
        print("inide setup  \(controller)")
        let channel = FlutterMethodChannel(name: "com.coditas.multi_window_native/pluginChannel", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
         guard let self = self else { return }
        switch call.method {
            case "generateUniqueTitle":
                guard let baseTitle = call.arguments as? String else {
                    result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                    return
                }
                let uniqueTitle = self.generateUniqueTitle(baseTitle: baseTitle)
                result(uniqueTitle)
                return
            case "registerWindowTitle":
                guard let title = call.arguments as? String else {
                    result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                    return
                }
                self.registeredWindowTitles.insert(title)
                result(true)
                return
            case "unregisterWindowTitle":
                guard let title = call.arguments as? String else {
                    result(FlutterError(code: "ARG_ERROR", message: "Expected String", details: nil))
                    return
                }
                self.registeredWindowTitles.remove(title)
                result(true)
                return
            case "notifyUiReady":
            // Now safe to show window
                DispatchQueue.main.async {
                controller.view.window?.makeKeyAndOrderFront(nil)
                result(true)
                }
                return
            case "createWindow":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "ARG_ERROR", message: "Expected dictionary", details: nil))
                    return
                }

                // Convert dictionary values to list of strings
                let argsList: [String] = [
                    args["routeName"] as? String ?? "",
                    args["theme"] as? String ?? "",
                    args["argsJson"] as? String ?? ""
                ]
                self.createNewWindow(with: argsList) { success in result(success) }
                return
            case "closeWindow":
                print("Inside close of secondary \(controller.view.window!)")
                self.closeWindow(controller.view.window!)
                result(true)
                return
            case "getMessengerCount":
                result(Self.messengers.count)
                return
            default:
                // Broadcast to all windows for EVERY other method
                self.broadcastToAllWindows(method: call.method, arguments: call.arguments)
                result(true)
            }
        }
    }
    
    // Register messenger for new window
    private func registerMessenger(_ messenger: FlutterBinaryMessenger, controller: FlutterViewController) {
        // Always (re-)wire the per-controller channel handler — the closure
        // captures `controller` so the notifyUiReady case knows which
        // window to bring to the front. Skipping this when the messenger
        // is already in the broadcast list (which now happens because
        // `register(with:)` appends `registrar.messenger` itself) would
        // leave the sub-window invisible because no one would call
        // `controller.view.window?.makeKeyAndOrderFront(nil)`.
        setupChannelHandler(for: messenger, controller: controller)
        if !Self.messengers.contains(where: { $0 === messenger }) {
            Self.messengers.append(messenger)
        }
    }
    
    // Create a new secondary window
    private  func createNewWindow(with args: [String], completion: @escaping (Bool) -> Void) {
        print("Creating new window with args: \(args)")
            let flutterProject = FlutterDartProject()
            flutterProject.dartEntrypointArguments = args
            let engine = FlutterEngine(name: "multi-window-engine-\(UUID().uuidString)", project: flutterProject)
            let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)

            // Run engine and show window
            engine.run(withEntrypoint: "main")

             // ⚡ Call the callback to register all plugins
            MultiWindowNativePlugin.onEngineCreatedCallback?(engine)
            
            // Use an NSPanel (.nonactivatingPanel + .utilityWindow) instead
            // of a regular NSWindow so the secondary window:
            //   - Sits above fullscreened apps via `.fullScreenAuxiliary`
            //   - Doesn't steal focus when shown (.nonactivatingPanel)
            //   - Stays visible across Spaces via `.canJoinAllSpaces`
            //
            // `.screenSaver` is the highest standard user-space window
            // level, so trainer apps (Zwift / MyWhoosh / Rouvy) running
            // in native fullscreen don't sit above it.
            //
            // Initial size is intentionally small; consumers can resize
            // via `window_manager.setSize(...)` after the engine boots.
            //
            // Style mask intentionally omits `.titled` — the overlay has
            // no title bar; the Flutter content fills the entire panel
            // and provides its own drag handle via
            // `window_manager.startDragging()`.
            let contentRect = NSMakeRect(0, 0, 220, 140)
            let styleMask: NSWindow.StyleMask = [
                .borderless,
                .resizable,
                .nonactivatingPanel,
            ]
            let newWindow = NSPanel(
                contentRect: contentRect,
                styleMask: styleMask,
                backing: .buffered,
                defer: true
            )
            newWindow.isFloatingPanel = true
            newWindow.becomesKeyOnlyIfNeeded = true
            newWindow.hidesOnDeactivate = false
            newWindow.level = .screenSaver
            newWindow.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle,
            ]
            newWindow.minSize = NSSize(width: 160, height: 80)
            newWindow.isMovableByWindowBackground = true
            newWindow.center()
            newWindow.delegate = self

            registerMessenger(engine.binaryMessenger, controller: controller)
           
            newWindow.contentViewController = controller
            secondaryWindowControllers.append((newWindow, controller))
            
            // Ensure the render pipeline is properly initialized
            controller.engine.viewController?.view.setNeedsDisplay(controller.view.bounds)
    }
    
    // Close a window (handles both main and secondary windows)
    private func closeWindow(_ win: NSWindow) {
        print("inside close")
        if win == mainWindow {
            for (window, controller) in secondaryWindowControllers {
                let engine = controller.engine
                let messenger = engine.binaryMessenger
                
                engine.viewController = nil
                window.delegate = nil
                window.contentViewController = nil
                engine.shutDownEngine()
                Self.messengers.removeAll(where: { $0 === messenger })
                window.close()
            }
            secondaryWindowControllers.removeAll()
            Self.messengers.removeAll()
            NSApp.terminate(self)
        } else {
            if let index = secondaryWindowControllers.firstIndex(where: { $0.window == win }) {
                let controller = secondaryWindowControllers[index].flutterViewController
                let engine = controller.engine
                let messenger = engine.binaryMessenger
                let window = secondaryWindowControllers[index].window
                
                // Allow Flutter's onWindowClose to execute before shutting down
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    engine.viewController = nil
                    window.delegate = nil
                    window.contentViewController = nil
                    engine.shutDownEngine()
                    Self.messengers.removeAll(where: { $0 === messenger })
                }
                
                // Close window immediately for visual feedback
                window.close()
                secondaryWindowControllers.remove(at: index)
            }
        }
    }
    
    // Broadcast method calls to all window messengers
    private func broadcastToAllWindows(method: String, arguments: Any?) {
        print("Broadcasting to \(Self.messengers.count) messengers")
        for messenger in Self.messengers {
            let channel = FlutterMethodChannel(name: "com.coditas.multi_window_native/pluginChannel", binaryMessenger: messenger) // Fix: Use Self.channelName
            channel.invokeMethod(method, arguments: arguments)
        }
    }
    
    // NSWindowDelegate method
    public func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            closeWindow(window)
        }
    }
    
    // Handle window becoming active/focused
    public func windowDidBecomeKey(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        guard let controller = win.contentViewController as? FlutterViewController else { return }
        
        // Notify Flutter engine that window is now active
        // This ensures the render pipeline resumes properly
        print("Window became key: \(win)")
        controller.engine.viewController?.view.setNeedsDisplay(controller.view.bounds)
    }
    
    // Handle dock icon click when windows are hidden
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows where !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
    
    // Prevent app from terminating after last window closes
    // public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    //     return true
    // }



}