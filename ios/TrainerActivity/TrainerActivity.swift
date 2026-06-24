import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// Must match the App Group declared on the Runner and the extension targets,
// and the value passed to `LiveActivities().init(appGroupId:)` in the Dart
// `IosOverlayController`.
let sharedDefault = UserDefaults(suiteName: "group.de.jonasbark.swiftcontrol.overlay")!

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
            let s = GearSnapshot.fromLiveActivity(context.attributes, defaults: sharedDefault)
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
            let s = GearSnapshot.fromLiveActivity(context.attributes, defaults: sharedDefault)
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
                    modePill(s.mode)
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
                Text(s.compactTrailing)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            } minimal: {
                Text(s.minimalText)
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
    private func primaryRow(_ s: GearSnapshot) -> some View {
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

    /// Row 2: SIM/ERG pill on the left, opted-in metrics in the middle,
    /// stop / end-ride button on the right. The stop button is rendered
    /// in this shared row so it shows up on both surfaces:
    ///   - the lock-screen / banner layout
    ///   - the expanded Dynamic Island
    /// (The compact / minimal Dynamic Island layouts have no room for a
    /// secondary control.)
    @ViewBuilder
    private func bottomRow(_ s: GearSnapshot) -> some View {
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
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: StopRideIntent()) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
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
}
