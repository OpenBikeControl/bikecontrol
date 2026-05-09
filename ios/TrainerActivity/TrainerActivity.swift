import ActivityKit
import SwiftUI
import WidgetKit

// Must match the App Group declared on the Runner and the extension targets,
// and the value passed to `LiveActivities().init(appGroupId:)` in the Dart
// `IosOverlayController`.
let sharedDefault = UserDefaults(suiteName: "group.de.jonasbark.swiftcontrol.overlay")!

@main
struct TrainerWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            TrainerActivity()
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct TrainerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock Screen / Banner
            let attrs = context.attributes
            let gear = sharedDefault.integer(forKey: attrs.prefixedKey("gear"))
            let maxGear = sharedDefault.integer(forKey: attrs.prefixedKey("maxGear"))
            let mode = sharedDefault.string(forKey: attrs.prefixedKey("mode")) ?? "sim"
            let powerW = sharedDefault.object(forKey: attrs.prefixedKey("powerW")) as? Int
            let cadenceRpm = sharedDefault.object(forKey: attrs.prefixedKey("cadenceRpm")) as? Int
            let showPower = sharedDefault.bool(forKey: attrs.prefixedKey("showPower"))
            let showCadence = sharedDefault.bool(forKey: attrs.prefixedKey("showCadence"))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BikeControl").font(.caption2).foregroundStyle(.secondary)
                    Text("\(gear) / \(maxGear)").font(.system(size: 36, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mode.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                    if showPower, let w = powerW {
                        Text("\(w) W").font(.caption.monospacedDigit())
                    }
                    if showCadence, let rpm = cadenceRpm {
                        Text("\(rpm) rpm").font(.caption.monospacedDigit())
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.4))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            let attrs = context.attributes
            let gear = sharedDefault.integer(forKey: attrs.prefixedKey("gear"))
            let maxGear = sharedDefault.integer(forKey: attrs.prefixedKey("maxGear"))
            let mode = sharedDefault.string(forKey: attrs.prefixedKey("mode")) ?? "sim"
            let powerW = sharedDefault.object(forKey: attrs.prefixedKey("powerW")) as? Int
            let cadenceRpm = sharedDefault.object(forKey: attrs.prefixedKey("cadenceRpm")) as? Int
            let ergTargetW = sharedDefault.object(forKey: attrs.prefixedKey("ergTargetW")) as? Int
            let showPower = sharedDefault.bool(forKey: attrs.prefixedKey("showPower"))
            let showCadence = sharedDefault.bool(forKey: attrs.prefixedKey("showCadence"))
            let showErgTarget = sharedDefault.bool(forKey: attrs.prefixedKey("showErgTarget"))

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(gear)/\(maxGear)").font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(mode.uppercased()).font(.caption2.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if showPower, let w = powerW {
                            Label("\(w) W", systemImage: "bolt.fill")
                        }
                        if showCadence, let rpm = cadenceRpm {
                            Label("\(rpm) rpm", systemImage: "arrow.clockwise")
                        }
                        if showErgTarget, let t = ergTargetW {
                            Label("tgt \(t) W", systemImage: "scope")
                        }
                    }.font(.caption.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "gear")
            } compactTrailing: {
                Text("\(gear)/\(maxGear)").font(.caption2.monospacedDigit())
            } minimal: {
                Text("\(gear)").font(.caption2.bold())
            }
        }
    }
}
