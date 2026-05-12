import AppIntents
import Foundation

// Names matched in AppDelegate.swift's Darwin-notification observers.
private let darwinDecrement = "de.jonasbark.swiftcontrol.overlay.action.decrement" as CFString
private let darwinIncrement = "de.jonasbark.swiftcontrol.overlay.action.increment" as CFString

private func postDarwin(_ name: CFString) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(name),
        nil, nil, true
    )
}

/// Fired by the `-` button in the Live Activity. Posts a Darwin notification
/// the main BikeControl process is listening for; the main app then dispatches
/// `def.shiftDown()` / `setManualErgPower(... -5)` depending on the active
/// trainer mode.
@available(iOS 17.0, *)
struct ShiftPrimaryDecrementIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Shift Down"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        postDarwin(darwinDecrement)
        return .result()
    }
}

/// Fired by the `+` button in the Live Activity.
@available(iOS 17.0, *)
struct ShiftPrimaryIncrementIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Shift Up"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        postDarwin(darwinIncrement)
        return .result()
    }
}
