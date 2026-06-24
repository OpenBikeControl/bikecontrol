import SwiftUI

/// Display-only gear readout rendered into the PiP window. Visually mirrors the
/// Live Activity's non-control layout (mode pill + opted-in metrics), scaled up
/// for the small floating window. No buttons — PiP is display-only.
@available(iOS 16.0, *)
struct GearReadoutView: View {
    let snapshot: GearSnapshot

    var body: some View {
        VStack(spacing: 8) {
            Text(snapshot.primaryText)
                .font(.system(size: 84, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            HStack(spacing: 12) {
                Self.modePill(snapshot.mode)
                if snapshot.showPower, let w = snapshot.powerW { Self.metric("\(w) W") }
                if snapshot.showCadence, let rpm = snapshot.cadenceRpm { Self.metric("\(rpm) rpm") }
                if !snapshot.isErg && snapshot.showGearRatio {
                    Self.metric(String(format: "×%.2f", snapshot.gearRatio))
                }
            }
            .font(.system(size: 22, weight: .semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    static func modePill(_ mode: String) -> some View {
        Text(mode.uppercased())
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor)
            .clipShape(Capsule())
    }

    static func metric(_ text: String) -> some View {
        Text(text).foregroundStyle(.white).lineLimit(1)
    }
}
