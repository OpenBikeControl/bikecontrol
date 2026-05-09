import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TrainerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainerActivityAttributes.self) { context in
            // Lock Screen / Banner
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BikeControl").font(.caption2).foregroundStyle(.secondary)
                    Text("\(context.state.gear) / \(context.state.maxGear)")
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.mode.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                    if context.state.showPower, let w = context.state.powerW {
                        Text("\(w) W").font(.caption.monospacedDigit())
                    }
                    if context.state.showCadence, let rpm = context.state.cadenceRpm {
                        Text("\(rpm) rpm").font(.caption.monospacedDigit())
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.4))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.gear)/\(context.state.maxGear)")
                        .font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.mode.uppercased())
                        .font(.caption2.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if context.state.showPower, let w = context.state.powerW {
                            Label("\(w) W", systemImage: "bolt.fill")
                        }
                        if context.state.showCadence, let rpm = context.state.cadenceRpm {
                            Label("\(rpm) rpm", systemImage: "arrow.clockwise")
                        }
                        if context.state.showErgTarget, let t = context.state.ergTargetW {
                            Label("tgt \(t) W", systemImage: "scope")
                        }
                    }.font(.caption.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "gear")
            } compactTrailing: {
                Text("\(context.state.gear)/\(context.state.maxGear)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Text("\(context.state.gear)").font(.caption2.bold())
            }
        }
    }
}
