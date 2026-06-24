import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Channel that delivers Live Activity button taps from the Widget
  /// Extension into the main Flutter engine. `IosOverlayController` registers
  /// a MethodCallHandler on this channel; native code below forwards Darwin
  /// notifications posted by the extension's `AppIntent`s.
  private static let overlayActionsChannel = "bike_control/overlay_actions_ios"
  private static let pipChannelName = "bike_control/pip_ios"

  private var actionChannel: FlutterMethodChannel?
  private var pipChannel: FlutterMethodChannel?

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

    if pipChannel == nil,
       let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BikeControlPip") {
      let channel = FlutterMethodChannel(
        name: AppDelegate.pipChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "isSupported":
          if #available(iOS 16.0, *) {
            result(DeviceCapabilities.pipEligible)
          } else {
            result(false)
          }
        case "start":
          if #available(iOS 16.0, *) {
            PipGearController.shared.start(initial: call.arguments as? [String: Any] ?? [:])
          }
          result(nil)
        case "update":
          if #available(iOS 16.0, *) {
            PipGearController.shared.update(call.arguments as? [String: Any] ?? [:])
          }
          result(nil)
        case "stop":
          if #available(iOS 16.0, *) {
            PipGearController.shared.stop()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      pipChannel = channel
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
