import Flutter
import HealthKit

/// Heart rate from Apple Health for the sensor hub. Two paths:
///  - iOS 26+: our own HKWorkoutSession, which is what makes AirPods Pro 3
///    sample continuously. The workout is DISCARDED on stop — the session
///    exists only to keep the earbuds sampling, never to write a workout
///    next to the trainer app's own Health upload.
///  - older iOS, or session failure: a passive anchored query that only sees
///    what other apps' workouts write. Reported as mode "passive" so the UI
///    can say why the tile is sparse.
/// Contract (names, payloads) is pinned by health_kit_channel_test.dart.
final class HealthKitHeartRate: NSObject, FlutterStreamHandler {
  static let methodChannelName = "bike_control/health_kit"
  static let eventChannelName = "bike_control/health_kit/heart_rate"

  private let store = HKHealthStore()
  private let heartRateType = HKQuantityType(.heartRate)
  private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
  private var sink: FlutterEventSink?

  private var query: HKAnchoredObjectQuery?
  private var sessionBox: AnyObject?   // HKWorkoutSession, boxed to keep the class iOS 17-loadable
  private var builderBox: AnyObject?   // HKLiveWorkoutBuilder

  func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BikeControlHealthKit") else { return }
    let method = FlutterMethodChannel(name: Self.methodChannelName, binaryMessenger: registrar.messenger())
    method.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "isAvailable":
        result(HKHealthStore.isHealthDataAvailable())
      case "authorize":
        self.authorize(result)
      case "start":
        self.start(result)
      case "stop":
        self.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let event = FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: registrar.messenger())
    event.setStreamHandler(self)
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // MARK: Authorization

  private func authorize(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      return result(FlutterError(code: "unavailable", message: "HealthKit not available", details: nil))
    }
    let workoutType = HKObjectType.workoutType()
    store.requestAuthorization(toShare: [workoutType], read: [heartRateType]) { [weak self] _, error in
      guard let self else { return }
      if let error {
        return result(FlutterError(code: "authorize", message: error.localizedDescription, details: nil))
      }
      // Read denials are invisible by design; the share half is the only
      // observable verdict.
      switch self.store.authorizationStatus(for: workoutType) {
      case .sharingDenied: result("denied")
      case .sharingAuthorized: result("granted")
      default: result("unknown")
      }
    }
  }

  // MARK: Start / stop

  private func start(_ result: @escaping FlutterResult) {
    stop()
    if #available(iOS 26.0, *), startSession() {
      emit(["mode": "session"])
    } else {
      startPassive()
      emit(["mode": "passive"])
    }
    result(nil)
  }

  private func stop() {
    if #available(iOS 26.0, *) { endSession() }
    if let query {
      store.stop(query)
      self.query = nil
      store.disableBackgroundDelivery(for: heartRateType) { _, _ in }
    }
  }

  private func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in self?.sink?(payload) }
  }

  private func emitError(code: String, _ message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(FlutterError(code: code, message: message, details: nil))
    }
  }

  private func emitSample(_ quantity: HKQuantity, at date: Date, mode: String) {
    let bpm = Int(quantity.doubleValue(for: bpmUnit).rounded())
    emit(["bpm": bpm, "at": Int(date.timeIntervalSince1970 * 1000), "mode": mode])
  }

  // MARK: Passive path

  private func startPassive() {
    let since = Date()
    let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
    let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void =
      { [weak self] _, samples, _, _, error in
        guard let self else { return }
        if let error { return self.emitError(code: "query", error.localizedDescription) }
        for case let sample as HKQuantitySample in samples ?? [] {
          self.emitSample(sample.quantity, at: sample.startDate, mode: "passive")
        }
      }
    let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil,
                                      limit: HKObjectQueryNoLimit, resultsHandler: handler)
    query.updateHandler = handler
    self.query = query
    store.execute(query)
    store.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { [weak self] ok, error in
      if let error, !ok { self?.emitError(code: "query", error.localizedDescription) }
    }
  }

  // MARK: Session path (iOS 26+)

  @available(iOS 26.0, *)
  private func startSession() -> Bool {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .cycling
    configuration.locationType = .indoor
    do {
      let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      let dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
      // Don't rely on the default typesToCollect for .cycling on iPhone —
      // ask for heart rate explicitly so the builder is guaranteed to
      // collect it regardless of the activity/location default set.
      dataSource.enableCollection(for: heartRateType, predicate: nil)
      builder.dataSource = dataSource
      builder.delegate = self
      session.delegate = self
      sessionBox = session
      builderBox = builder
      let now = Date()
      session.startActivity(with: now)
      builder.beginCollection(withStart: now) { [weak self] ok, error in
        guard let error, !ok else { return }
        // beginCollection's completion runs off-main; hop before touching
        // sessionBox, and re-check identity — a stop()+start() in between
        // may already have replaced this session with a newer one.
        DispatchQueue.main.async { [weak self] in
          guard let self, session === (self.sessionBox as AnyObject?) else { return }
          self.fallBackToPassive(from: session, builder: builder, reason: error.localizedDescription)
        }
      }
      return true
    } catch {
      emitError(code: "session", error.localizedDescription)
      sessionBox = nil
      builderBox = nil
      return false
    }
  }

  @available(iOS 26.0, *)
  private func endSession() {
    guard let session = sessionBox as? HKWorkoutSession, let builder = builderBox as? HKLiveWorkoutBuilder else { return }
    sessionBox = nil
    builderBox = nil
    session.end()
    builder.endCollection(withEnd: Date()) { _, _ in
      // Never finish or save the workout: the session only exists to keep
      // AirPods sampling. Discarding leaves no "Indoor Cycling" in Fitness.
      builder.discardWorkout()
    }
  }

  /// Main-thread only, and only for a session that identity-checked as
  /// still current: an async session failure (failed `beginCollection`, a
  /// delegate-reported error, or the OS ending the session) must not leave
  /// the shim silently stuck in mode "session" with no query running — it
  /// degrades to the passive path instead, same as a synchronous
  /// `startSession()` failure does via `start()`'s `else` branch.
  @available(iOS 26.0, *)
  private func fallBackToPassive(from session: HKWorkoutSession, builder: HKLiveWorkoutBuilder, reason: String) {
    emitError(code: "session", reason)
    sessionBox = nil
    builderBox = nil
    // The session may still be .running here (e.g. a beginCollection
    // failure arrives after startActivity already succeeded) — end() it or
    // it's orphaned running and blocks a later startSession() from ever
    // succeeding again. Harmless if it already ended on its own.
    session.end()
    // discardWorkout() is documented (HKWorkoutBuilder.h) as finishing the
    // build and discarding the result itself — it doesn't require a
    // preceding endCollection(withEnd:), unlike the happy-path stop in
    // endSession().
    builder.discardWorkout()
    startPassive()
    emit(["mode": "passive"])
  }
}

@available(iOS 26.0, *)
extension HealthKitHeartRate: HKLiveWorkoutBuilderDelegate {
  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    guard collectedTypes.contains(heartRateType),
          let statistics = workoutBuilder.statistics(for: heartRateType),
          let latest = statistics.mostRecentQuantity(),
          let interval = statistics.mostRecentQuantityDateInterval() else { return }
    emitSample(latest, at: interval.start, mode: "session")
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

@available(iOS 26.0, *)
extension HealthKitHeartRate: HKWorkoutSessionDelegate {
  // Both methods below run on "an anonymous serial background queue"
  // (HKWorkoutSession.h), never main — every touch of sessionBox/builderBox
  // must happen after hopping to main, and only for the session that's
  // still current: a stale delegate callback from an already-replaced
  // session (e.g. stop() immediately followed by start()) must be a no-op,
  // not clobber the new session's state or emit a spurious error for it.

  func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                      from fromState: HKWorkoutSessionState, date: Date) {
    // The OS ending the session out from under us (e.g. another app started
    // one) is a post-start failure the Dart side records; the hub's
    // drop-out path handles the resulting silence.
    guard toState == .ended else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, workoutSession === (self.sessionBox as AnyObject?),
            let builder = self.builderBox as? HKLiveWorkoutBuilder else { return }
      self.fallBackToPassive(from: workoutSession, builder: builder, reason: "workout session ended by the system")
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    DispatchQueue.main.async { [weak self] in
      guard let self, workoutSession === (self.sessionBox as AnyObject?),
            let builder = self.builderBox as? HKLiveWorkoutBuilder else { return }
      self.fallBackToPassive(from: workoutSession, builder: builder, reason: error.localizedDescription)
    }
  }
}
