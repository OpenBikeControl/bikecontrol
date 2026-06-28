import Foundation

/// Shared gear readout model. Compiled into BOTH the Runner app (for PiP) and
/// the TrainerActivity extension (for the Live Activity), so the two surfaces
/// always agree on field semantics.
struct GearSnapshot {
    let gear: Int
    let maxGear: Int
    let mode: String          // "sim" | "erg"
    let powerW: Int?
    let cadenceRpm: Int?
    let ergTargetW: Int?
    let gearRatio: Double
    let showPower: Bool
    let showCadence: Bool
    let showErgTarget: Bool
    let showGearRatio: Bool
    let showControls: Bool
    let frontShiftEnabled: Bool
    let frontRingLarge: Bool

    var isErg: Bool { mode == "erg" }

    /// Head-unit-style `front×rear` position notation used when the virtual
    /// front derailleur is on (small ring = 1, large ring = 2, e.g. `2×14`).
    private var positionGear: String { "\(frontRingLarge ? 2 : 1)×\(gear)" }

    /// Big primary value: target watts in ERG, gear in SIM.
    var primaryText: String {
        if isErg { return ergTargetW.map { "\($0) W" } ?? "-- W" }
        if frontShiftEnabled { return positionGear }
        return "\(gear)/\(maxGear)"
    }

    var compactTrailing: String {
        if isErg { return ergTargetW.map { "\($0)W" } ?? "--W" }
        if frontShiftEnabled { return positionGear }
        return "\(gear)/\(maxGear)"
    }

    var minimalText: String {
        if isErg { return ergTargetW.map { "\($0)" } ?? "--" }
        if frontShiftEnabled { return positionGear }
        return "\(gear)"
    }

    /// Cheap change-detection key so the PiP pump can skip identical frames.
    var contentHash: Int {
        var h = Hasher()
        h.combine(gear); h.combine(maxGear); h.combine(mode)
        h.combine(powerW); h.combine(cadenceRpm); h.combine(ergTargetW)
        h.combine(gearRatio); h.combine(showPower); h.combine(showCadence)
        h.combine(showErgTarget); h.combine(showGearRatio); h.combine(showControls)
        h.combine(frontShiftEnabled); h.combine(frontRingLarge)
        return h.finalize()
    }
}

extension GearSnapshot {
    /// Parse the map sent over `bike_control/pip_ios` — the same shape produced
    /// by `overlayStateToActivityMap` on the Dart side. Missing keys fall back
    /// to safe defaults so a malformed message can never crash the renderer.
    static func fromMap(_ m: [String: Any]) -> GearSnapshot {
        func optInt(_ key: String) -> Int? { m[key] as? Int }
        return GearSnapshot(
            gear: m["gear"] as? Int ?? 0,
            maxGear: m["maxGear"] as? Int ?? 0,
            mode: m["mode"] as? String ?? "sim",
            powerW: optInt("powerW"),
            cadenceRpm: optInt("cadenceRpm"),
            ergTargetW: optInt("ergTargetW"),
            gearRatio: m["gearRatio"] as? Double ?? 1.0,
            showPower: m["showPower"] as? Bool ?? false,
            showCadence: m["showCadence"] as? Bool ?? false,
            showErgTarget: m["showErgTarget"] as? Bool ?? false,
            showGearRatio: m["showGearRatio"] as? Bool ?? false,
            showControls: m["showControls"] as? Bool ?? false,
            frontShiftEnabled: m["frontShiftEnabled"] as? Bool ?? false,
            frontRingLarge: m["frontRingLarge"] as? Bool ?? false
        )
    }
}
