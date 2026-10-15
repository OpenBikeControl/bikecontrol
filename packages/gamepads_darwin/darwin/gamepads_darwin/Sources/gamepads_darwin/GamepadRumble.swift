import Foundation
import GameController
import CoreHaptics

@available(macOS 11.0, iOS 14.0, *)
final class GamepadRumble {
    private final class Effect {
        let controller: GCController
        var engines: [CHHapticEngine] = []
        var players: [CHHapticPatternPlayer] = []
        init(_ controller: GCController) { self.controller = controller }
        func stop() {
            for player in players { try? player.stop(atTime: CHHapticTimeImmediate) }
            players.removeAll()
        }
        deinit {
            stop()
            for engine in engines { engine.stop(completionHandler: nil) }
        }
    }
    private var effects: [ObjectIdentifier: Effect] = [:]
    private var disconnectObserver: NSObjectProtocol?

    init() {
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] notification in
            if let controller = notification.object as? GCController {
                self?.stop(controller)
            }
        }
    }
    deinit {
        if let observer = disconnectObserver { NotificationCenter.default.removeObserver(observer) }
        stopAll()
    }
    func has(_ controller: GCController) -> Bool {
        guard let haptics = controller.haptics else { return false }
        return haptics.supportedLocalities.contains(.default) ||
            haptics.supportedLocalities.contains(.handles) ||
            haptics.supportedLocalities.contains(.leftHandle) ||
            haptics.supportedLocalities.contains(.rightHandle)
    }
    func set(_ controller: GCController, low: Double, high: Double, duration: Int) -> Bool {
        guard low.isFinite, high.isFinite, (0...1).contains(low),
              (0...1).contains(high), (0...30000).contains(duration) else { return false }
        if duration == 0 || (low == 0 && high == 0) { stop(controller); return true }
        guard has(controller), let haptics = controller.haptics else { return false }
        let key = ObjectIdentifier(controller)
        let effect = effects[key] ?? Effect(controller)
        effect.stop()
        let stereo = haptics.supportedLocalities.contains(.leftHandle) &&
            haptics.supportedLocalities.contains(.rightHandle)
        let localities: [GCHapticsLocality]
        if stereo {
            localities = [.leftHandle, .rightHandle]
        } else if haptics.supportedLocalities.contains(.default) {
            localities = [.default]
        } else if haptics.supportedLocalities.contains(.handles) {
            localities = [.handles]
        } else if haptics.supportedLocalities.contains(.leftHandle) {
            localities = [.leftHandle]
        } else {
            localities = [.rightHandle]
        }
        do {
            if effect.engines.isEmpty {
                for locality in localities {
                    guard let engine = haptics.createEngine(withLocality: locality) else { return false }
                    engine.isAutoShutdownEnabled = true
                    effect.engines.append(engine)
                }
            }
            for (index, engine) in effect.engines.enumerated() {
                let intensity = stereo ? (index == 0 ? low : high) : max(low, high)
                if intensity == 0 { continue }
                try engine.start()
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: stereo && index == 1 ? 1 : 0)
                ], relativeTime: 0, duration: Double(duration) / 1000)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                effect.players.append(player)
                try player.start(atTime: CHHapticTimeImmediate)
            }
            effects[key] = effect
            return true
        } catch {
            effect.stop()
            effects.removeValue(forKey: key)
            return false
        }
    }
    func stop(_ controller: GCController) {
        effects.removeValue(forKey: ObjectIdentifier(controller))?.stop()
    }
    func stopAll() {
        for effect in effects.values { effect.stop() }
        effects.removeAll()
    }
}
