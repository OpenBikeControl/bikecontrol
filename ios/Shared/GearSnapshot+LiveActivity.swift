import ActivityKit
import Foundation

@available(iOS 16.1, *)
extension GearSnapshot {
    /// Read the live_activities plugin's id-prefixed App Group keys (used by the
    /// Lock-Screen / Dynamic Island widget). Lives in a TrainerActivity-target-ONLY
    /// file (NOT compiled into Runner) because `LiveActivitiesAppAttributes` is
    /// defined in the widget extension target. Keeping it out of the shared
    /// `GearSnapshot.swift` lets that file compile into Runner without ActivityKit.
    static func fromLiveActivity(_ attrs: LiveActivitiesAppAttributes, defaults: UserDefaults) -> GearSnapshot {
        func k(_ s: String) -> String { attrs.prefixedKey(s) }
        func optInt(_ key: String) -> Int? { defaults.object(forKey: key) as? Int }
        return GearSnapshot(
            gear: defaults.integer(forKey: k("gear")),
            maxGear: defaults.integer(forKey: k("maxGear")),
            mode: defaults.string(forKey: k("mode")) ?? "sim",
            powerW: optInt(k("powerW")),
            cadenceRpm: optInt(k("cadenceRpm")),
            ergTargetW: optInt(k("ergTargetW")),
            gearRatio: defaults.double(forKey: k("gearRatio")),
            showPower: defaults.bool(forKey: k("showPower")),
            showCadence: defaults.bool(forKey: k("showCadence")),
            showErgTarget: defaults.bool(forKey: k("showErgTarget")),
            showGearRatio: defaults.bool(forKey: k("showGearRatio")),
            showControls: defaults.bool(forKey: k("showControls")),
            frontShiftEnabled: defaults.bool(forKey: k("frontShiftEnabled")),
            frontRingLarge: defaults.bool(forKey: k("frontRingLarge"))
        )
    }
}
