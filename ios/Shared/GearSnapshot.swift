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

    var isErg: Bool { mode == "erg" }

    /// Big primary value: target watts in ERG, gear N/M in SIM.
    var primaryText: String {
        if isErg { return ergTargetW.map { "\($0) W" } ?? "-- W" }
        return "\(gear) / \(maxGear)"
    }

    var compactTrailing: String {
        isErg ? (ergTargetW.map { "\($0)W" } ?? "--W") : "\(gear)/\(maxGear)"
    }

    var minimalText: String {
        isErg ? (ergTargetW.map { "\($0)" } ?? "--") : "\(gear)"
    }

    /// Cheap change-detection key so the PiP pump can skip identical frames.
    var contentHash: Int {
        var h = Hasher()
        h.combine(gear); h.combine(maxGear); h.combine(mode)
        h.combine(powerW); h.combine(cadenceRpm); h.combine(ergTargetW)
        h.combine(gearRatio); h.combine(showPower); h.combine(showCadence)
        h.combine(showErgTarget); h.combine(showGearRatio); h.combine(showControls)
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
            showControls: m["showControls"] as? Bool ?? false
        )
    }
}
