import Cocoa
import FlutterMacOS

public class KeypressSimulatorMacosPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.leanflutter.plugins/keypress_simulator", binaryMessenger: registrar.messenger)
        let instance = KeypressSimulatorMacosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAccessAllowed":
            isAccessAllowed(call, result: result)
            break
        case "requestAccess":
            requestAccess(call, result: result)
            break
        case "simulateKeyPress":
            simulateKeyPress(call, result: result)
            break
        case "simulateMouseClick":
            simulateMouseClick(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    public func isAccessAllowed(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(AXIsProcessTrusted())
    }

    public func requestAccess(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let onlyOpenPrefPane: Bool = args["onlyOpenPrefPane"] as! Bool

        if (!onlyOpenPrefPane) {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        } else  {
            let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(prefpaneUrl)
        }
        result(true)
    }

    public func simulateKeyPress(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]

        let keyCode: Int? = args["keyCode"] as? Int
        let modifiers: Array<String> = args["modifiers"] as! Array<String>
        let keyDown: Bool = args["keyDown"] as! Bool

        let event = _createKeyPressEvent(keyCode, modifiers, keyDown);
        event.post(tap: .cghidEventTap);
        result(true)
    }


    public func simulateMouseClick(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]

        let x: Double = args["x"] as! Double
        let y: Double = args["y"] as! Double

        let point = CGPoint(x: x, y: y)

        // Move mouse to the point
        /*let move = CGEvent(mouseEventSource: nil,
                           mouseType: .mouseMoved,
                           mouseCursorPosition: point,
                           mouseButton: .left)
        move?.post(tap: .cghidEventTap)*/

        // Mouse down
        let mouseDown = CGEvent(mouseEventSource: nil,
                                mouseType: .leftMouseDown,
                                mouseCursorPosition: point,
                                mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)

        // Mouse up
        let mouseUp = CGEvent(mouseEventSource: nil,
                              mouseType: .leftMouseUp,
                              mouseCursorPosition: point,
                              mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        result(true)
    }

    public func _createKeyPressEvent(_ keyCode: Int?, _ modifiers: Array<String>, _ keyDown: Bool) -> CGEvent {
        let virtualKey: CGKeyCode = CGKeyCode(UInt32(keyCode ?? 0))
        var flags: CGEventFlags = CGEventFlags()

        if (modifiers.contains("shiftModifier")) {
            flags.insert(CGEventFlags.maskShift)
        }
        if (modifiers.contains("controlModifier")) {
            flags.insert(CGEventFlags.maskControl)
        }
        if (modifiers.contains("altModifier")) {
            flags.insert(CGEventFlags.maskAlternate)
        }
        if (modifiers.contains("metaModifier")) {
            flags.insert(CGEventFlags.maskCommand)
        }
        if (modifiers.contains("functionModifier")) {
            flags.insert(CGEventFlags.maskSecondaryFn)
        }
        let eventKeyPress = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: keyDown);
        eventKeyPress!.flags = flags
        return eventKeyPress!
    }
}
