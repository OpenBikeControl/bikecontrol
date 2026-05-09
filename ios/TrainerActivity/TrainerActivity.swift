import ActivityKit
import SwiftUI
import WidgetKit

// Must match the App Group declared on the Runner and the extension targets,
// and the value passed to `LiveActivities().init(appGroupId:)` in the Dart
// `IosOverlayController`.
private let appGroupId = "group.de.jonasbark.swiftcontrol.overlay"
private let sharedDefaults = UserDefaults(suiteName: appGroupId)!

@main
struct TrainerActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            TrainerActivity()
        }
    }
}

@available(iOS 16.1, *)
struct TrainerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock Screen / Banner
            let s = readState(context.attributes)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BikeControl").font(.caption2).foregroundStyle(.secondary)
                    Text("\(s.gear) / \(s.maxGear)")
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(s.mode.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                    if s.showPower, let w = s.powerW {
                        Text("\(w) W").font(.caption.monospacedDigit())
                    }
                    if s.showCadence, let rpm = s.cadenceRpm {
                        Text("\(rpm) rpm").font(.caption.monospacedDigit())
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.4))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            let s = readState(context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(s.gear)/\(s.maxGear)").font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(s.mode.uppercased()).font(.caption2.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if s.showPower, let w = s.powerW {
                            Label("\(w) W", systemImage: "bolt.fill")
                        }
                        if s.showCadence, let rpm = s.cadenceRpm {
                            Label("\(rpm) rpm", systemImage: "arrow.clockwise")
                        }
                        if s.showErgTarget, let t = s.ergTargetW {
                            Label("tgt \(t) W", systemImage: "scope")
                        }
                    }.font(.caption.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "gear")
            } compactTrailing: {
                let s = readState(context.attributes)
                Text("\(s.gear)/\(s.maxGear)").font(.caption2.monospacedDigit())
            } minimal: {
                let s = readState(context.attributes)
                Text("\(s.gear)").font(.caption2.bold())
            }
        }
    }
}

// MARK: - Shared-defaults state

private struct TrainerState {
    var gear: Int
    var maxGear: Int
    var mode: String
    var powerW: Int?
    var cadenceRpm: Int?
    var ergTargetW: Int?
    var showPower: Bool
    var showCadence: Bool
    var showErgTarget: Bool
    var showGearRatio: Bool
    var gearRatio: Double
}

@available(iOS 16.1, *)
private func readState(_ attrs: LiveActivitiesAppAttributes) -> TrainerState {
    func k(_ s: String) -> String { attrs.prefixedKey(s) }
    func optInt(_ key: String) -> Int? {
        sharedDefaults.object(forKey: key) as? Int
    }
    return TrainerState(
        gear: sharedDefaults.integer(forKey: k("gear")),
        maxGear: sharedDefaults.integer(forKey: k("maxGear")),
        mode: sharedDefaults.string(forKey: k("mode")) ?? "sim",
        powerW: optInt(k("powerW")),
        cadenceRpm: optInt(k("cadenceRpm")),
        ergTargetW: optInt(k("ergTargetW")),
        showPower: sharedDefaults.bool(forKey: k("showPower")),
        showCadence: sharedDefaults.bool(forKey: k("showCadence")),
        showErgTarget: sharedDefaults.bool(forKey: k("showErgTarget")),
        showGearRatio: sharedDefaults.bool(forKey: k("showGearRatio")),
        gearRatio: sharedDefaults.double(forKey: k("gearRatio"))
    )
}
