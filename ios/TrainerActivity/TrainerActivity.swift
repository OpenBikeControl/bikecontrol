import ActivityKit
import SwiftUI
import WidgetKit

// Must match the App Group declared on the Runner and the extension targets,
// and the value passed to `LiveActivities().init(appGroupId:)` in the Dart
// `IosOverlayController`.
let sharedDefault = UserDefaults(suiteName: "group.de.jonasbark.swiftcontrol.overlay")!

// MARK: - Snapshot

private struct TrainerSnapshot {
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

    var isErg: Bool { mode == "erg" }

    /// Big primary value: target watts in ERG, gear N/M in SIM.
    var primaryText: String {
        if isErg {
            if let w = ergTargetW { return "\(w) W" }
            return "-- W"
        } else {
            return "\(gear) / \(maxGear)"
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private func snapshot(for attrs: LiveActivitiesAppAttributes) -> TrainerSnapshot {
    func k(_ s: String) -> String { attrs.prefixedKey(s) }
    func optInt(_ key: String) -> Int? {
        sharedDefault.object(forKey: key) as? Int
    }
    return TrainerSnapshot(
        gear: sharedDefault.integer(forKey: k("gear")),
        maxGear: sharedDefault.integer(forKey: k("maxGear")),
        mode: sharedDefault.string(forKey: k("mode")) ?? "sim",
        powerW: optInt(k("powerW")),
        cadenceRpm: optInt(k("cadenceRpm")),
        ergTargetW: optInt(k("ergTargetW")),
        gearRatio: sharedDefault.double(forKey: k("gearRatio")),
        showPower: sharedDefault.bool(forKey: k("showPower")),
        showCadence: sharedDefault.bool(forKey: k("showCadence")),
        showErgTarget: sharedDefault.bool(forKey: k("showErgTarget")),
        showGearRatio: sharedDefault.bool(forKey: k("showGearRatio"))
    )
}

// MARK: - Bundle entry point

@main
struct TrainerWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            TrainerActivity()
        }
    }
}

// MARK: - Activity

@available(iOSApplicationExtension 16.1, *)
struct TrainerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock Screen / banner — mirrors the Flutter compact 2-row layout.
            let s = snapshot(for: context.attributes)
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    // SF Symbol stand-in for the app icon. Embedding the real
                    // icon would require adding an Asset Catalog entry to the
                    // Widget Extension target in Xcode.
                    Image(systemName: "bicycle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(s.primaryText)
                        .font(.system(size: 30, weight: .heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer().frame(width: 22)
                }
                bottomRow(s)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            let s = snapshot(for: context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(s.primaryText)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    modePill(s.mode)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomRow(s)
                }
            } compactLeading: {
                Image(systemName: "gear")
            } compactTrailing: {
                Text(compactTrailing(s))
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
            } minimal: {
                Text(minimalText(s))
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
        }
    }

    /// Row 2: SIM/ERG pill on the left, opted-in metrics on the right.
    @ViewBuilder
    private func bottomRow(_ s: TrainerSnapshot) -> some View {
        HStack(spacing: 10) {
            modePill(s.mode)
            Spacer()
            if s.showPower, let w = s.powerW {
                metric("\(w) W")
            }
            if s.showCadence, let rpm = s.cadenceRpm {
                metric("\(rpm) rpm")
            }
            if !s.isErg && s.showGearRatio {
                metric(String(format: "×%.2f", s.gearRatio))
            }
        }
        .font(.caption.monospacedDigit())
    }

    private func modePill(_ mode: String) -> some View {
        Text(mode.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor)
            .clipShape(Capsule())
    }

    private func metric(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }

    /// Compact-trailing on the Dynamic Island: very tight, ~8 chars max.
    private func compactTrailing(_ s: TrainerSnapshot) -> String {
        s.isErg
            ? (s.ergTargetW.map { "\($0)W" } ?? "--W")
            : "\(s.gear)/\(s.maxGear)"
    }

    /// Minimal Dynamic Island: just the gear number or the watts target.
    private func minimalText(_ s: TrainerSnapshot) -> String {
        s.isErg
            ? (s.ergTargetW.map { "\($0)" } ?? "--")
            : "\(s.gear)"
    }
}
