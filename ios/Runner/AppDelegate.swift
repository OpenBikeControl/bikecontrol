import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel that delivers Live Activity button taps from the Widget
  /// Extension into the main Flutter engine. `IosOverlayController` registers
  /// a MethodCallHandler on this channel; native code below forwards Darwin
  /// notifications posted by the extension's `AppIntent`s.
  private static let overlayActionsChannel = "bike_control/overlay_actions_ios"

  private var actionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // The Darwin observer can be registered before the Flutter engine exists.
    // Invocations are guarded by `actionChannel != nil`; we just queue work
    // until the channel is wired up in `didInitializeImplicitFlutterEngine`.
    registerOverlayActionObservers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Scene-based apps don't expose a FlutterViewController via AppDelegate's
    // `window` (the scene delegate owns the window), so wire the MethodChannel
    // off the implicit engine's plugin registry instead — that's where the
    // binary messenger lives in this lifecycle.
    if actionChannel == nil,
       let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BikeControlOverlayActions") {
      actionChannel = FlutterMethodChannel(
        name: AppDelegate.overlayActionsChannel,
        binaryMessenger: registrar.messenger()
      )
    }
  }

  // MARK: - Live Activity Darwin notification bridge

  private func registerOverlayActionObservers() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passUnretained(self).toOpaque()

    let names: [CFString] = [
      "de.jonasbark.swiftcontrol.overlay.action.decrement" as CFString,
      "de.jonasbark.swiftcontrol.overlay.action.increment" as CFString,
      "de.jonasbark.swiftcontrol.overlay.action.stop" as CFString,
    ]

    for name in names {
      CFNotificationCenterAddObserver(
        center,
        observer,
        { _, observer, name, _, _ in
          guard let observer = observer, let name = name else { return }
          let self_ = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
          let nameString = name.rawValue as String
          let action: String
          if nameString.hasSuffix("decrement") {
            action = "primaryDecrement"
          } else if nameString.hasSuffix("increment") {
            action = "primaryIncrement"
          } else if nameString.hasSuffix("stop") {
            action = "stop"
          } else {
            return
          }
          DispatchQueue.main.async {
            self_.actionChannel?.invokeMethod("action", arguments: action)
          }
        },
        name,
        nil,
        .deliverImmediately
      )
    }
  }

  deinit {
    CFNotificationCenterRemoveEveryObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque()
    )
  }
}
