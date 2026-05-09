import ActivityKit
import Foundation

public struct TrainerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var gear: Int
        public var maxGear: Int
        public var mode: String        // "sim" | "erg"
        public var powerW: Int?
        public var cadenceRpm: Int?
        public var ergTargetW: Int?
        public var showPower: Bool
        public var showCadence: Bool
        public var showErgTarget: Bool
        public var showGearRatio: Bool
        public var gearRatio: Double

        public init(
            gear: Int, maxGear: Int, mode: String,
            powerW: Int?, cadenceRpm: Int?, ergTargetW: Int?,
            showPower: Bool, showCadence: Bool, showErgTarget: Bool, showGearRatio: Bool,
            gearRatio: Double
        ) {
            self.gear = gear
            self.maxGear = maxGear
            self.mode = mode
            self.powerW = powerW
            self.cadenceRpm = cadenceRpm
            self.ergTargetW = ergTargetW
            self.showPower = showPower
            self.showCadence = showCadence
            self.showErgTarget = showErgTarget
            self.showGearRatio = showGearRatio
            self.gearRatio = gearRatio
        }
    }

    public init() {}
}
