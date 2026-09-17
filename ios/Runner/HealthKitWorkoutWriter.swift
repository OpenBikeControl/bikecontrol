import Flutter
import HealthKit
import UIKit

/// Writes finished rides to Apple Health ("Save rides to Apple Health").
///
/// Separate from `HealthKitHeartRate`: that shim's live session is always
/// discarded and only exists to keep AirPods sampling. This one builds a
/// real workout with HKWorkoutBuilder (works on every supported iOS
/// version) from the samples the Dart recorder collected.
/// Contract (names, payload) is pinned by health_workout_channel_test.dart.
final class HealthKitWorkoutWriter: NSObject {
  static let channelName = "bike_control/health_kit/workouts"

  private let store = HKHealthStore()
  private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
  private let metersPerSecond = HKUnit.meter().unitDivided(by: .second())

  func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BikeControlHealthKitWorkouts") else { return }
    let method = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    method.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "isAvailable":
        result(HKHealthStore.isHealthDataAvailable())
      case "authorize":
        self.authorize(result)
      case "saveWorkout":
        guard let args = call.arguments as? [String: Any] else {
          return result(FlutterError(code: "arguments", message: "saveWorkout expects a map", details: nil))
        }
        self.save(args, result)
      case "openHealthSettings":
        self.openHealthSettings()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: Authorization

  /// Everything a ride writes. Power, cadence and speed types only exist on
  /// iOS 17+; below that those samples are simply not written.
  private var shareTypes: Set<HKSampleType> {
    var types: Set<HKSampleType> = [
      HKObjectType.workoutType(),
      HKQuantityType(.distanceCycling),
      HKQuantityType(.activeEnergyBurned),
      HKQuantityType(.heartRate),
    ]
    if #available(iOS 17.0, *) {
      types.formUnion([
        HKQuantityType(.cyclingPower),
        HKQuantityType(.cyclingCadence),
        HKQuantityType(.cyclingSpeed),
      ])
    }
    return types
  }

  /// Note for anyone debugging this: with LLDB attached (flutter run / Xcode)
  /// the permission sheet never appears — the process is frozen while the
  /// sheet's remote view is presented and healthd times the session out after
  /// ~30 s ("Authorization session timed out"). Launched without a debugger
  /// (devicectl, TestFlight, App Store) the sheet shows instantly.
  private func authorize(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      return result(FlutterError(code: "unavailable", message: "HealthKit not available", details: nil))
    }
    // Read stays exactly what the heart-rate source already asks for.
    store.requestAuthorization(toShare: shareTypes, read: [HKQuantityType(.heartRate)]) { [weak self] _, error in
      let verdict: Any
      if let error {
        verdict = FlutterError(code: "authorize", message: error.localizedDescription, details: nil)
      } else if let self {
        // Only the share half is observable; the workout type stands in for
        // the whole set.
        switch self.store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingDenied: verdict = "denied"
        case .sharingAuthorized: verdict = "granted"
        default: verdict = "unknown"
        }
      } else {
        verdict = "unknown"
      }
      // HealthKit completions run off-main; FlutterResult must not.
      DispatchQueue.main.async { result(verdict) }
    }
  }

  // MARK: Saving

  private func save(_ args: [String: Any], _ result: @escaping FlutterResult) {
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }

    guard HKHealthStore.isHealthDataAvailable() else {
      return reply(FlutterError(code: "unavailable", message: "HealthKit not available", details: nil))
    }
    if store.authorizationStatus(for: HKObjectType.workoutType()) != .sharingAuthorized {
      return reply(FlutterError(code: "denied", message: "Not allowed to save workouts to Health", details: nil))
    }
    guard let syncId = args["syncId"] as? String,
          let syncVersion = (args["syncVersion"] as? NSNumber)?.intValue,
          let start = Self.date(args["start"]),
          let end = Self.date(args["end"]),
          end > start else {
      return reply(FlutterError(code: "arguments", message: "saveWorkout payload incomplete", details: nil))
    }

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .cycling
    configuration.locationType = .indoor
    let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
    let metadata: [String: Any] = [
      HKMetadataKeyIndoorWorkout: true,
      HKMetadataKeySyncIdentifier: syncId,
      HKMetadataKeySyncVersion: syncVersion,
    ]
    let events = pauseEvents(args["pauses"])
    let samples = buildSamples(args)

    // Every step's error ends the chain: the half-built workout is thrown
    // away and the error goes back to Dart as a PlatformException.
    let fail: (String, Error?) -> Void = { step, error in
      builder.discardWorkout()
      reply(Self.flutterError(step: step, error))
    }

    builder.beginCollection(withStart: start) { ok, error in
      guard ok else { return fail("beginCollection", error) }
      builder.addMetadata(metadata) { ok, error in
        guard ok else { return fail("addMetadata", error) }
        self.addEvents(events, to: builder) { ok, error in
          guard ok else { return fail("addEvents", error) }
          self.addSamples(samples, to: builder) { ok, error in
            guard ok else { return fail("addSamples", error) }
            builder.endCollection(withEnd: end) { ok, error in
              guard ok else { return fail("endCollection", error) }
              builder.finishWorkout { workout, error in
                guard let workout else { return fail("finishWorkout", error) }
                reply(workout.uuid.uuidString)
              }
            }
          }
        }
      }
    }
  }

  private func addEvents(_ events: [HKWorkoutEvent], to builder: HKWorkoutBuilder,
                         completion: @escaping (Bool, Error?) -> Void) {
    guard !events.isEmpty else { return completion(true, nil) }
    builder.addWorkoutEvents(events, completion: completion)
  }

  private func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder,
                          completion: @escaping (Bool, Error?) -> Void) {
    guard !samples.isEmpty else { return completion(true, nil) }
    builder.add(samples, completion: completion)
  }

  /// Pause/resume pairs, so the workout's duration is the active time.
  private func pauseEvents(_ raw: Any?) -> [HKWorkoutEvent] {
    guard let pairs = raw as? [[NSNumber]] else { return [] }
    var events: [HKWorkoutEvent] = []
    for pair in pairs where pair.count == 2 {
      let pausedAt = Date(timeIntervalSince1970: pair[0].doubleValue / 1000)
      let resumedAt = Date(timeIntervalSince1970: pair[1].doubleValue / 1000)
      guard resumedAt > pausedAt else { continue }
      events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pausedAt, duration: 0), metadata: nil))
      events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: resumedAt, duration: 0), metadata: nil))
    }
    return events
  }

  private func buildSamples(_ args: [String: Any]) -> [HKSample] {
    var samples: [HKSample] = []
    if #available(iOS 17.0, *) {
      samples += instantSamples(args["power"], type: HKQuantityType(.cyclingPower), unit: .watt())
      samples += instantSamples(args["cadence"], type: HKQuantityType(.cyclingCadence), unit: bpmUnit)
      samples += instantSamples(args["speed"], type: HKQuantityType(.cyclingSpeed), unit: metersPerSecond)
    }
    samples += instantSamples(args["heartRate"], type: HKQuantityType(.heartRate), unit: bpmUnit)
    samples += intervalSamples(args["distance"], type: HKQuantityType(.distanceCycling), unit: .meter())
    samples += intervalSamples(args["energy"], type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
    return samples
  }

  /// `{t: [ms], v: [value]}` → zero-length quantity samples.
  private func instantSamples(_ raw: Any?, type: HKQuantityType, unit: HKUnit) -> [HKSample] {
    guard let series = raw as? [String: Any],
          let times = series["t"] as? [NSNumber],
          let values = series["v"] as? [NSNumber],
          times.count == values.count else { return [] }
    return zip(times, values).map { time, value in
      let at = Date(timeIntervalSince1970: time.doubleValue / 1000)
      return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value.doubleValue),
                              start: at, end: at)
    }
  }

  /// `{s: [ms], e: [ms], v: [amount]}` → cumulative quantity samples.
  private func intervalSamples(_ raw: Any?, type: HKQuantityType, unit: HKUnit) -> [HKSample] {
    guard let series = raw as? [String: Any],
          let starts = series["s"] as? [NSNumber],
          let ends = series["e"] as? [NSNumber],
          let values = series["v"] as? [NSNumber],
          starts.count == ends.count, starts.count == values.count else { return [] }
    var samples: [HKSample] = []
    for index in starts.indices {
      let start = Date(timeIntervalSince1970: starts[index].doubleValue / 1000)
      let end = Date(timeIntervalSince1970: ends[index].doubleValue / 1000)
      guard end > start, values[index].doubleValue > 0 else { continue }
      samples.append(HKQuantitySample(type: type,
                                      quantity: HKQuantity(unit: unit, doubleValue: values[index].doubleValue),
                                      start: start, end: end))
    }
    return samples
  }

  private static func date(_ raw: Any?) -> Date? {
    guard let ms = raw as? NSNumber else { return nil }
    return Date(timeIntervalSince1970: ms.doubleValue / 1000)
  }

  /// Authorization failures get code `denied` so Dart can offer the Health
  /// settings; everything else keeps the failing step as its code.
  private static func flutterError(step: String, _ error: Error?) -> FlutterError {
    if let hkError = error as? HKError,
       hkError.code == .errorAuthorizationDenied || hkError.code == .errorAuthorizationNotDetermined {
      return FlutterError(code: "denied", message: hkError.localizedDescription, details: step)
    }
    return FlutterError(code: "save", message: error?.localizedDescription ?? "\(step) failed", details: step)
  }

  // MARK: Settings

  /// The Health app is where sharing permissions live; fall back to the
  /// app's own Settings page if it can't be opened (e.g. on iPad without it).
  private func openHealthSettings() {
    guard let health = URL(string: "x-apple-health://") else { return }
    UIApplication.shared.open(health) { opened in
      guard !opened, let settings = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(settings)
    }
  }
}
