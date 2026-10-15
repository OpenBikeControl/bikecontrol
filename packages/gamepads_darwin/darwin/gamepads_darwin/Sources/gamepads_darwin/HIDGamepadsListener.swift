#if os(macOS)
import Foundation
import GameController
import IOKit.hid

/// A raw input change of a generic HID gamepad.
struct HIDGamepadEvent {
    let type: String
    let key: String
    let value: Double
}

/// Reads generic HID gamepads and joysticks that the GameController framework
/// doesn't support (e.g. many DirectInput/PS3/PC pads), so they work at all.
///
/// They have no fixed layout, so they emit raw keys like gamepads_windows:
/// "button-N", "axis-N" (-1.0 to 1.0) and, for the first hat switch, the
/// regular d-pad keys. Further hat switches emit "switchN-dpadUp" etc.
///
/// IOHIDManager delivers input whichever app has focus.
@available(macOS 11.0, *)
class HIDGamepadsListener {
    private(set) var gamepads: [HIDGamepad] = []
    var listener: ((String, HIDGamepadEvent) -> Void)?
    var connectionListener: ((String, String, Bool) -> Void)?

    private let manager: IOHIDManager
    private var nextId = 0

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching = [kHIDUsage_GD_Joystick, kHIDUsage_GD_GamePad, kHIDUsage_GD_MultiAxisController].map {
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDGamepadsListener>.fromOpaque(context).takeUnretainedValue().addGamepad(device: device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDGamepadsListener>.fromOpaque(context).takeUnretainedValue().removeGamepad(device: device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("gamepads_darwin: IOHIDManagerOpen failed: \(result)")
        }
    }

    deinit {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func addGamepad(device: IOHIDDevice) {
        // GameController handles these itself (with proper key names).
        guard !GCController.supportsHIDDevice(device) else { return }
        guard !gamepads.contains(where: { $0.device === device }) else { return }

        let id = "hid-\(nextId)"
        nextId += 1
        let gamepad = HIDGamepad(id: id, device: device)
        gamepad.listener = { [weak self] event in self?.listener?(id, event) }
        gamepads.append(gamepad)
        connectionListener?(id, gamepad.name, true)
    }

    private func removeGamepad(device: IOHIDDevice) {
        let removed = gamepads.filter { $0.device === device }
        gamepads.removeAll { $0.device === device }
        for gamepad in removed {
            gamepad.stop()
            connectionListener?(gamepad.id, gamepad.name, false)
        }
    }
}

@available(macOS 11.0, *)
class HIDGamepad {
    let id: String
    let device: IOHIDDevice
    let name: String
    var listener: ((HIDGamepadEvent) -> Void)?

    private var buttons: [IOHIDElementCookie: Int] = [:]
    private var axes: [IOHIDElementCookie: Int] = [:]
    private var hats: [IOHIDElementCookie: Int] = [:]
    /// Last reported axis values, to ignore sensor noise.
    private var axisValues: [IOHIDElementCookie: Double] = [:]
    private var hatDirections: [IOHIDElementCookie: [Bool]] = [:]

    private static let dpadKeys = ["dpadUp", "dpadRight", "dpadDown", "dpadLeft"]
    private static let axisUsages: Set<Int> = [
        kHIDUsage_GD_X, kHIDUsage_GD_Y, kHIDUsage_GD_Z,
        kHIDUsage_GD_Rx, kHIDUsage_GD_Ry, kHIDUsage_GD_Rz,
        kHIDUsage_GD_Slider, kHIDUsage_GD_Dial, kHIDUsage_GD_Wheel,
    ]

    init(id: String, device: IOHIDDevice) {
        self.id = id
        self.device = device
        name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Gamepad"

        let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone))
            as? [IOHIDElement] ?? []
        var buttonElements: [IOHIDElement] = []
        var axisElements: [IOHIDElement] = []
        var hatElements: [IOHIDElement] = []
        for element in elements {
            let type = IOHIDElementGetType(element)
            guard type == kIOHIDElementTypeInput_Button || type == kIOHIDElementTypeInput_Misc
                || type == kIOHIDElementTypeInput_Axis else { continue }
            let page = Int(IOHIDElementGetUsagePage(element))
            let usage = Int(IOHIDElementGetUsage(element))
            if page == kHIDPage_Button {
                buttonElements.append(element)
            } else if page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Hatswitch {
                hatElements.append(element)
            } else if page == kHIDPage_GenericDesktop && HIDGamepad.axisUsages.contains(usage) {
                axisElements.append(element)
            }
        }
        // Number by usage, so the numbering doesn't depend on report layout.
        let byUsage = { (a: IOHIDElement, b: IOHIDElement) in IOHIDElementGetUsage(a) < IOHIDElementGetUsage(b) }
        for (i, element) in buttonElements.sorted(by: byUsage).enumerated() {
            buttons[IOHIDElementGetCookie(element)] = i
        }
        for (i, element) in axisElements.sorted(by: byUsage).enumerated() {
            let cookie = IOHIDElementGetCookie(element)
            axes[cookie] = i
            // The resting state isn't reported, so e.g. a trigger axis resting
            // at -1.0 doesn't fire on connect.
            axisValues[cookie] = currentValue(of: element).map { HIDGamepad.normalizedAxis(element, $0) }
        }
        for (i, element) in hatElements.enumerated() {
            let cookie = IOHIDElementGetCookie(element)
            hats[cookie] = i
            hatDirections[cookie] = currentValue(of: element).map { HIDGamepad.hatDirections(element, $0) }
                ?? [false, false, false, false]
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(device, { context, _, _, value in
            guard let context else { return }
            Unmanaged<HIDGamepad>.fromOpaque(context).takeUnretainedValue().onValue(value)
        }, context)
    }

    func stop() {
        IOHIDDeviceRegisterInputValueCallback(device, nil, nil)
        listener = nil
    }

    private func currentValue(of element: IOHIDElement) -> Int? {
        let placeholder = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, 0, 0)
        return withExtendedLifetime(placeholder) {
            var value = Unmanaged.passUnretained(placeholder)
            guard IOHIDDeviceGetValue(device, element, &value) == kIOReturnSuccess else { return nil }
            return IOHIDValueGetIntegerValue(value.takeUnretainedValue())
        }
    }

    private func onValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let cookie = IOHIDElementGetCookie(element)
        let raw = IOHIDValueGetIntegerValue(value)

        if let index = buttons[cookie] {
            listener?(HIDGamepadEvent(type: "button", key: "button-\(index)", value: raw != 0 ? 1.0 : 0.0))
        } else if let index = axes[cookie] {
            let normalized = HIDGamepad.normalizedAxis(element, raw)
            // Ignore sensor noise.
            if let previous = axisValues[cookie], abs(normalized - previous) < 0.02 { return }
            axisValues[cookie] = normalized
            listener?(HIDGamepadEvent(type: "analog", key: "axis-\(index)", value: normalized))
        } else if let index = hats[cookie] {
            let directions = HIDGamepad.hatDirections(element, raw)
            let previous = hatDirections[cookie] ?? [false, false, false, false]
            hatDirections[cookie] = directions
            let prefix = index == 0 ? "" : "switch\(index)-"
            for d in 0..<4 where directions[d] != previous[d] {
                listener?(HIDGamepadEvent(type: "button", key: prefix + HIDGamepad.dpadKeys[d],
                                          value: directions[d] ? 1.0 : 0.0))
            }
        }
    }

    /// Maps the element's logical range to -1.0 ... 1.0.
    static func normalizedAxis(_ element: IOHIDElement, _ raw: Int) -> Double {
        let min = Double(IOHIDElementGetLogicalMin(element))
        let max = Double(IOHIDElementGetLogicalMax(element))
        guard max > min else { return 0 }
        return Swift.min(1, Swift.max(-1, (Double(raw) - min) / (max - min) * 2 - 1))
    }

    /// Which of up, right, down, left a hat switch value presses. Values
    /// outside the logical range mean centered.
    static func hatDirections(_ element: IOHIDElement, _ raw: Int) -> [Bool] {
        let min = IOHIDElementGetLogicalMin(element)
        let max = IOHIDElementGetLogicalMax(element)
        guard raw >= min && raw <= max else { return [false, false, false, false] }
        let position = raw - min
        if max - min == 3 {
            // 4-way hat: up, right, down, left.
            return (0..<4).map { $0 == position }
        }
        // 8-way hat, clockwise from up.
        switch position {
        case 0: return [true, false, false, false]
        case 1: return [true, true, false, false]
        case 2: return [false, true, false, false]
        case 3: return [false, true, true, false]
        case 4: return [false, false, true, false]
        case 5: return [false, false, true, true]
        case 6: return [false, false, false, true]
        case 7: return [true, false, false, true]
        default: return [false, false, false, false]
        }
    }
}
#endif
