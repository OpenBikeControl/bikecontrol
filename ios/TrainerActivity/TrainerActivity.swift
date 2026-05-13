import ActivityKit
import AppIntents
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
    let showControls: Bool

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
        showGearRatio: sharedDefault.bool(forKey: k("showGearRatio")),
        showControls: sharedDefault.bool(forKey: k("showControls"))
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
            // `.environment(\.colorScheme, .dark)` forces light-on-dark text on
            // every device regardless of the user's system appearance, matching
            // the dark `activityBackgroundTint`.
            let s = snapshot(for: context.attributes)
            VStack(spacing: 4) {
                primaryRow(s)
                bottomRow(s)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .environment(\.colorScheme, .dark)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            let s = snapshot(for: context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(s.primaryText)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // The mode pill already shows in the bottom row, so the
                    // trailing region is more useful as a stop / end-ride
                    // button. Tapping it disconnects the trainer and tears
                    // down the Live Activity on the Dart side.
                    if #available(iOSApplicationExtension 17.0, *) {
                        Button(intent: StopRideIntent()) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    } else {
                        modePill(s.mode)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomRow(s)
                        .environment(\.colorScheme, .dark)
                }
            } compactLeading: {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } compactTrailing: {
                Text(compactTrailing(s))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            } minimal: {
                Text(minimalText(s))
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }

    /// Row 1: app glyph + big primary value, OR − / + buttons flanking the
    /// primary when `OverlayField.controls` is enabled (iOS 17+ only — the
    /// `AppIntent`-driven `Button(intent:)` initialiser requires it).
    @ViewBuilder
    private func primaryRow(_ s: TrainerSnapshot) -> some View {
        if s.showControls, #available(iOSApplicationExtension 17.0, *) {
            HStack(spacing: 12) {
                Button(intent: ShiftPrimaryDecrementIntent()) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Text(s.primaryText)
                    .font(.system(size: 30, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)

                Button(intent: ShiftPrimaryIncrementIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 8) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Spacer()
                Text(s.primaryText)
                    .font(.system(size: 30, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Spacer().frame(width: 22)
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
        .foregroundStyle(.white)
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
            .foregroundStyle(.white)
            .lineLimit(1)
            .contentTransition(.numericText())
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
