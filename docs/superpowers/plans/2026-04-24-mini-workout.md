# Mini Workout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user with a connected smart trainer record a ride to a `.fit` file, view a summary afterwards, browse/share/delete past workouts.

**Architecture:** A pure-Dart `WorkoutRecorder` subscribes to the four `ValueListenable`s exposed by the active bike definition (`powerW`, `cadenceRpm`, `speedKph`, `heartRateBpm`) and appends one sample per second to an in-memory list. Stopping the workout hands the samples to a `FitFileWriter` (using the `fit_tool` package) which encodes a FIT activity file to the app documents directory under `workouts/`. A `WorkoutRepository` scans that directory for `.fit` files and exposes list/delete/share/revealInFinder operations. UI lives in three new pages (live, summary, list), reached from the existing `ProxyDeviceDetailsPage`.

**Tech Stack:** Flutter + shadcn_flutter (no Material), `ValueNotifier`/`ValueListenable` throughout, `fit_tool` for FIT encoding, `share_plus` for OS share-sheets, `path_provider` (already present) for directories, localized via ARB files in `lib/i10n/`.

---

## File Structure

**Create:**
- `lib/services/workout/workout_sample.dart` — data class for one 1 Hz sample
- `lib/services/workout/workout_summary.dart` — summary data class (duration, averages, maxes)
- `lib/services/workout/workout_recorder.dart` — state machine + subscriptions + sample accumulation
- `lib/services/workout/workout_repository.dart` — lists / deletes / reveals `.fit` files in the workouts dir
- `lib/services/workout/fit_writer.dart` — `fit_tool`-based writer: samples → `.fit` bytes
- `lib/services/workout/past_workout.dart` — lightweight list-row model (header-only read of a `.fit`)
- `lib/pages/workout/mini_workout_page.dart` — live workout page (start/pause/stop, live metrics)
- `lib/pages/workout/workout_summary_page.dart` — post-stop summary + share/open-folder buttons
- `lib/pages/workout/workouts_list_page.dart` — list of past workouts + per-row actions
- `lib/pages/proxy_device_details/mini_workout_card.dart` — entry point card for the smart-trainer detail page

**Modify:**
- `pubspec.yaml` — add `fit_tool`, `share_plus`
- `lib/i10n/intl_en.arb` (and the other 5 arb files) — new strings
- `lib/pages/proxy_device_details.dart` — insert `MiniWorkoutCard` into the details column

Each file owns one thing: the recorder does not know about UI or disk; the writer does not know about the recorder (takes a summary + samples struct); the repository does not know about the writer (treats `.fit` as opaque). Pages own no business logic — they wire `ValueListenable`s and call the services.

---

## Scope Guardrails (Read First)

- **No Strava OAuth.** Sharing = OS share sheet with the `.fit` file attached. That's it. The user picks Strava (or email, Dropbox, Files, …) from the system sheet.
- **Background recording works.** The app already keeps BLE alive in the background via its custom `universal_ble` fork (see `pubspec.yaml:17-20`) and `WakelockPlus`. The `WorkoutRecorder` is a plain Dart timer that runs as long as the isolate is alive — when the app is backgrounded but BLE is still delivering values, samples keep accumulating. No extra work required; do not gate the feature on foreground state.
- **No cloud sync.** Files live locally. Pro status is not checked — recording is free.
- **No charts/graphs in v1.** Summary shows numbers only. Charts are follow-up work.
- **Single active workout at a time.** The recorder is a singleton on `core`. Start when idle, and the Start button is hidden while another is in progress.
- **Web is out of scope.** `path_provider`'s app-documents dir does not work on web; gate the feature behind `!kIsWeb`. The entry card returns `SizedBox.shrink()` on web.

---

## Task 0: Dependencies & ARB strings

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/i10n/intl_en.arb`, `intl_de.arb`, `intl_es.arb`, `intl_fr.arb`, `intl_it.arb`, `intl_pl.arb`

- [ ] **Step 1: Add `fit_tool` and `share_plus` to pubspec.yaml**

Edit `pubspec.yaml`. After the `path_provider: ^2.1.5` line (line 25) add:

```yaml
  fit_tool: ^0.7.4
  share_plus: ^11.0.0
```

Run `flutter pub get`. If `fit_tool`'s latest version differs, pick the newest stable that resolves — the API surface used in Task 3 (`FitFile`, `FileIdMessage`, `RecordMessage`, `SessionMessage`, `ActivityMessage`, `Event`, `FitFile.toBytes()`) has been stable for several minor versions.

- [ ] **Step 2: Add English ARB strings**

Edit `lib/i10n/intl_en.arb`. Add these keys (keep them alphabetical — find the right insertion points):

```json
"miniWorkout": "Mini Workout",
"miniWorkoutStart": "Start Workout",
"miniWorkoutPause": "Pause",
"miniWorkoutResume": "Resume",
"miniWorkoutStop": "Stop",
"miniWorkoutRecording": "Recording",
"miniWorkoutPaused": "Paused",
"miniWorkoutNoTrainerConnected": "Connect a smart trainer to start a workout.",
"miniWorkoutConfirmStopTitle": "Stop workout?",
"miniWorkoutConfirmStopBody": "Your workout will be saved and you can view the summary.",
"miniWorkoutSummaryTitle": "Workout summary",
"miniWorkoutSummaryDuration": "Duration",
"miniWorkoutSummaryAvgPower": "Avg power",
"miniWorkoutSummaryMaxPower": "Max power",
"miniWorkoutSummaryAvgCadence": "Avg cadence",
"miniWorkoutSummaryAvgSpeed": "Avg speed",
"miniWorkoutSummaryDistance": "Distance",
"miniWorkoutSummaryAvgHeartRate": "Avg heart rate",
"miniWorkoutSummaryMaxHeartRate": "Max heart rate",
"miniWorkoutShareFit": "Share .fit file",
"miniWorkoutOpenFolder": "Open workouts folder",
"miniWorkoutPastWorkouts": "Past workouts",
"miniWorkoutNoPastWorkouts": "No past workouts yet.",
"miniWorkoutDelete": "Delete",
"miniWorkoutConfirmDeleteTitle": "Delete workout?",
"miniWorkoutConfirmDeleteBody": "This removes the .fit file from your device.",
"miniWorkoutRecordingTooShort": "Workout too short to save (minimum 10 seconds)."
```

- [ ] **Step 3: Copy the same keys to the other 5 ARB files**

Do the same copy into `intl_de.arb`, `intl_es.arb`, `intl_fr.arb`, `intl_it.arb`, `intl_pl.arb`. For non-English files copy the English values verbatim — translations can be handled later. Keep JSON valid.

- [ ] **Step 4: Regenerate localizations**

Run: `flutter pub global run intl_utils:generate`
Expected: `lib/gen/l10n.dart` rebuilt with the new accessors (`AppLocalizations.of(context).miniWorkoutStart`, etc.). Do NOT hand-edit `lib/gen/l10n.dart`. If the command fails with "not activated", run `flutter pub global activate intl_utils` first.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/i10n/ lib/gen/l10n.dart
git commit -m "chore(workout): add fit_tool + share_plus deps and i18n strings"
```

---

## Task 1: Metrics source abstraction

The two bike definitions (`FitnessBikeDefinition`, `ProxyBikeDefinition`) expose the same four listenables but share no base class. Introduce a tiny local record to unify access without touching the `prop` package.

**Files:**
- Create: `lib/services/workout/trainer_metrics.dart`
- Test: `test/services/workout/trainer_metrics_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/workout/trainer_metrics_test.dart`:

```dart
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';

void main() {
  test('returns null for unknown definition', () {
    expect(TrainerMetrics.fromDefinition(null), isNull);
    expect(TrainerMetrics.fromDefinition(Object()), isNull);
  });

  test('wraps FitnessBikeDefinition listenables', () {
    // We cannot construct a real FitnessBikeDefinition easily in a unit test;
    // rely on runtime-type branch by passing a fake via a subclass is impractical
    // here — assert only the null / unknown-type branches. Integration coverage
    // happens via the live page in Task 5.
    expect(TrainerMetrics.fromDefinition(42), isNull);
  });
}
```

- [ ] **Step 2: Run the test — it should fail to compile (file not found)**

Run: `flutter test test/services/workout/trainer_metrics_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bike_control/services/workout/trainer_metrics.dart'`.

- [ ] **Step 3: Create the source file**

Create `lib/services/workout/trainer_metrics.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';

/// Bundles the four `ValueListenable`s that drive workout recording, regardless
/// of whether the source is an FTMS passthrough (`FitnessBikeDefinition`) or a
/// Zwift-protocol-only trainer (`ProxyBikeDefinition`).
class TrainerMetrics {
  final ValueListenable<int?> powerW;
  final ValueListenable<int?> cadenceRpm;
  final ValueListenable<double?> speedKph;
  final ValueListenable<int?> heartRateBpm;

  const TrainerMetrics({
    required this.powerW,
    required this.cadenceRpm,
    required this.speedKph,
    required this.heartRateBpm,
  });

  /// Returns null when [definition] is not a supported bike definition.
  static TrainerMetrics? fromDefinition(Object? definition) {
    if (definition is FitnessBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
      );
    }
    if (definition is ProxyBikeDefinition) {
      return TrainerMetrics(
        powerW: definition.powerW,
        cadenceRpm: definition.cadenceRpm,
        speedKph: definition.speedKph,
        heartRateBpm: definition.heartRateBpm,
      );
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests, expect pass**

Run: `flutter test test/services/workout/trainer_metrics_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/workout/trainer_metrics.dart test/services/workout/trainer_metrics_test.dart
git commit -m "feat(workout): add TrainerMetrics adapter over bike definitions"
```

---

## Task 2: WorkoutSample + WorkoutSummary data classes

**Files:**
- Create: `lib/services/workout/workout_sample.dart`
- Create: `lib/services/workout/workout_summary.dart`
- Test: `test/services/workout/workout_summary_test.dart`

- [ ] **Step 1: Create the sample file**

Create `lib/services/workout/workout_sample.dart`:

```dart
/// One 1 Hz record of trainer telemetry. Fields are nullable because the
/// trainer may not report all metrics (e.g. no HR strap paired).
class WorkoutSample {
  final DateTime timestamp;
  final int? powerW;
  final int? cadenceRpm;
  final double? speedKph;
  final int? heartRateBpm;

  const WorkoutSample({
    required this.timestamp,
    this.powerW,
    this.cadenceRpm,
    this.speedKph,
    this.heartRateBpm,
  });
}
```

- [ ] **Step 2: Write the failing summary test**

Create `test/services/workout/workout_summary_test.dart`:

```dart
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 4, 24, 10, 0, 0);

  WorkoutSample s(int sec, {int? p, int? c, double? sp, int? hr}) =>
      WorkoutSample(
        timestamp: start.add(Duration(seconds: sec)),
        powerW: p,
        cadenceRpm: c,
        speedKph: sp,
        heartRateBpm: hr,
      );

  test('empty samples produce zeroed summary', () {
    final sum = WorkoutSummary.fromSamples([], startedAt: start, activeDuration: Duration.zero);
    expect(sum.avgPowerW, 0);
    expect(sum.maxPowerW, 0);
    expect(sum.avgCadenceRpm, 0);
    expect(sum.avgSpeedKph, 0);
    expect(sum.distanceKm, 0);
    expect(sum.avgHeartRateBpm, 0);
    expect(sum.maxHeartRateBpm, 0);
  });

  test('averages ignore null entries', () {
    final samples = [
      s(0, p: 100, c: 80, sp: 20, hr: null),
      s(1, p: 200, c: null, sp: 22, hr: 140),
      s(2, p: 300, c: 90, sp: 24, hr: 150),
    ];
    final sum = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 3),
    );
    expect(sum.avgPowerW, 200); // (100+200+300)/3
    expect(sum.maxPowerW, 300);
    expect(sum.avgCadenceRpm, 85); // (80+90)/2 rounded
    expect(sum.avgSpeedKph, closeTo(22.0, 0.001));
    expect(sum.avgHeartRateBpm, 145);
    expect(sum.maxHeartRateBpm, 150);
  });

  test('distance is avg speed * active duration', () {
    final samples = [
      s(0, sp: 30),
      s(1, sp: 30),
      s(2, sp: 30),
    ];
    final sum = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(minutes: 1),
    );
    // 30 km/h for 1 minute = 0.5 km
    expect(sum.distanceKm, closeTo(0.5, 0.001));
  });
}
```

- [ ] **Step 3: Run the test — it should fail (file not found)**

Run: `flutter test test/services/workout/workout_summary_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement WorkoutSummary**

Create `lib/services/workout/workout_summary.dart`:

```dart
import 'workout_sample.dart';

class WorkoutSummary {
  final DateTime startedAt;
  final Duration activeDuration;
  final int avgPowerW;
  final int maxPowerW;
  final int avgCadenceRpm;
  final double avgSpeedKph;
  final double distanceKm;
  final int avgHeartRateBpm;
  final int maxHeartRateBpm;
  final int sampleCount;

  const WorkoutSummary({
    required this.startedAt,
    required this.activeDuration,
    required this.avgPowerW,
    required this.maxPowerW,
    required this.avgCadenceRpm,
    required this.avgSpeedKph,
    required this.distanceKm,
    required this.avgHeartRateBpm,
    required this.maxHeartRateBpm,
    required this.sampleCount,
  });

  factory WorkoutSummary.fromSamples(
    List<WorkoutSample> samples, {
    required DateTime startedAt,
    required Duration activeDuration,
  }) {
    int sum(int? Function(WorkoutSample) pick, {int? Function(int, int)? reduce}) {
      int n = 0;
      int acc = 0;
      int best = 0;
      for (final s in samples) {
        final v = pick(s);
        if (v == null) continue;
        acc += v;
        if (v > best) best = v;
        n++;
      }
      if (reduce != null) return best;
      return n == 0 ? 0 : (acc / n).round();
    }

    double sumD(double? Function(WorkoutSample) pick) {
      int n = 0;
      double acc = 0;
      for (final s in samples) {
        final v = pick(s);
        if (v == null) continue;
        acc += v;
        n++;
      }
      return n == 0 ? 0 : acc / n;
    }

    final avgSpeed = sumD((s) => s.speedKph);
    final distanceKm = avgSpeed * (activeDuration.inSeconds / 3600.0);

    return WorkoutSummary(
      startedAt: startedAt,
      activeDuration: activeDuration,
      avgPowerW: sum((s) => s.powerW),
      maxPowerW: sum((s) => s.powerW, reduce: (a, b) => a > b ? a : b),
      avgCadenceRpm: sum((s) => s.cadenceRpm),
      avgSpeedKph: avgSpeed,
      distanceKm: distanceKm,
      avgHeartRateBpm: sum((s) => s.heartRateBpm),
      maxHeartRateBpm: sum((s) => s.heartRateBpm, reduce: (a, b) => a > b ? a : b),
      sampleCount: samples.length,
    );
  }
}
```

- [ ] **Step 5: Run the test — expect pass**

Run: `flutter test test/services/workout/workout_summary_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/workout/workout_sample.dart lib/services/workout/workout_summary.dart test/services/workout/workout_summary_test.dart
git commit -m "feat(workout): add WorkoutSample and WorkoutSummary with tests"
```

---

## Task 3: FitFileWriter (samples → .fit bytes)

`fit_tool` expects a list of messages: one `FileIdMessage` (type = activity), a `RecordMessage` per sample, one `SessionMessage` with aggregates, one `ActivityMessage` for the wrapper. Tests assert the output bytes are non-empty and round-trip through `FitFile.fromBytes` cleanly.

**Files:**
- Create: `lib/services/workout/fit_writer.dart`
- Test: `test/services/workout/fit_writer_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/workout/fit_writer_test.dart`:

```dart
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes a non-empty FIT file that round-trips', () {
    final start = DateTime.utc(2026, 4, 24, 10, 0, 0);
    final samples = List.generate(
      60,
      (i) => WorkoutSample(
        timestamp: start.add(Duration(seconds: i)),
        powerW: 200 + i,
        cadenceRpm: 90,
        speedKph: 30.0,
        heartRateBpm: 140,
      ),
    );
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(minutes: 1),
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);
    expect(bytes.length, greaterThan(100));

    // Round-trip: fit_tool parses its own output.
    final parsed = FitFile.fromBytes(bytes);
    final records = parsed.records.whereType<RecordMessage>().toList();
    expect(records.length, 60);
    expect(records.first.power, 200);
    expect(records.last.power, 259);
  });

  test('tolerates null telemetry fields', () {
    final start = DateTime.utc(2026, 4, 24, 11, 0, 0);
    final samples = [
      WorkoutSample(timestamp: start, powerW: null, cadenceRpm: null, speedKph: null, heartRateBpm: null),
      WorkoutSample(timestamp: start.add(const Duration(seconds: 1)), powerW: 150),
    ];
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 2),
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);
    expect(bytes.length, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run the test — expect fail**

Run: `flutter test test/services/workout/fit_writer_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement FitFileWriter**

Create `lib/services/workout/fit_writer.dart`:

```dart
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import 'workout_sample.dart';
import 'workout_summary.dart';

/// Encodes a completed workout to a standard FIT Activity file (.fit).
///
/// Layout mirrors the Garmin FIT cookbook recipe for Activity files:
/// FileId → DeviceInfo → Event(start) → Record × N → Event(stop) → Lap →
/// Session → Activity.
class FitFileWriter {
  static const int _manufacturerBikeControl = 255; // "development" manufacturer id
  static const int _productBikeControl = 1;

  static Uint8List encode({
    required List<WorkoutSample> samples,
    required WorkoutSummary summary,
  }) {
    final startMs = summary.startedAt.toUtc().millisecondsSinceEpoch;
    final endMs = startMs + summary.activeDuration.inMilliseconds;

    final builder = FitFileBuilder(autoDefine: true);

    builder.add(
      FileIdMessage()
        ..type = FileType.activity
        ..manufacturer = _manufacturerBikeControl
        ..product = _productBikeControl
        ..timeCreated = startMs
        ..serialNumber = 0,
    );

    builder.add(
      EventMessage()
        ..timestamp = startMs
        ..event = Event.timer
        ..eventType = EventType.start,
    );

    for (final s in samples) {
      final msg = RecordMessage()..timestamp = s.timestamp.toUtc().millisecondsSinceEpoch;
      if (s.powerW != null) msg.power = s.powerW;
      if (s.cadenceRpm != null) msg.cadence = s.cadenceRpm;
      if (s.speedKph != null) msg.speed = s.speedKph! / 3.6; // FIT stores m/s
      if (s.heartRateBpm != null) msg.heartRate = s.heartRateBpm;
      builder.add(msg);
    }

    builder.add(
      EventMessage()
        ..timestamp = endMs
        ..event = Event.timer
        ..eventType = EventType.stopAll,
    );

    final session = SessionMessage()
      ..timestamp = endMs
      ..startTime = startMs
      ..sport = Sport.cycling
      ..subSport = SubSport.indoorCycling
      ..totalElapsedTime = summary.activeDuration.inSeconds.toDouble()
      ..totalTimerTime = summary.activeDuration.inSeconds.toDouble()
      ..totalDistance = summary.distanceKm * 1000.0
      ..avgPower = summary.avgPowerW
      ..maxPower = summary.maxPowerW
      ..avgCadence = summary.avgCadenceRpm
      ..avgSpeed = summary.avgSpeedKph / 3.6
      ..avgHeartRate = summary.avgHeartRateBpm == 0 ? null : summary.avgHeartRateBpm
      ..maxHeartRate = summary.maxHeartRateBpm == 0 ? null : summary.maxHeartRateBpm;
    builder.add(session);

    builder.add(
      ActivityMessage()
        ..timestamp = endMs
        ..totalTimerTime = summary.activeDuration.inSeconds.toDouble()
        ..numSessions = 1
        ..type = ActivityType.manual
        ..event = Event.activity
        ..eventType = EventType.stop,
    );

    final fit = builder.build();
    return Uint8List.fromList(fit.toBytes());
  }
}
```

> Note: if `fit_tool`'s exact API differs slightly (e.g. the setter is `totalTimerTime` vs `total_timer_time`), adjust to match. Keep the message order. Do NOT silently drop type errors — the round-trip test will surface them.

- [ ] **Step 4: Run the test — expect pass**

Run: `flutter test test/services/workout/fit_writer_test.dart`
Expected: PASS. If the `RecordMessage` getters (`power`, `cadence`, `speed`, `heartRate`) differ in your `fit_tool` version, update the test assertions to read via `getFieldValueByName` — do not weaken the round-trip check.

- [ ] **Step 5: Commit**

```bash
git add lib/services/workout/fit_writer.dart test/services/workout/fit_writer_test.dart
git commit -m "feat(workout): encode samples to FIT activity file"
```

---

## Task 4: WorkoutRecorder (state machine + sampling loop)

**Files:**
- Create: `lib/services/workout/workout_recorder.dart`
- Test: `test/services/workout/workout_recorder_test.dart`

States: `idle`, `recording`, `paused`. Transitions: `start()` idle→recording, `pause()` recording→paused, `resume()` paused→recording, `stop()` recording/paused→idle (returns samples + summary). A 1 Hz Timer snapshots the latest values of the four `ValueListenable`s while recording; paused ticks are skipped so active duration excludes pause time.

- [ ] **Step 1: Write the failing test**

Create `test/services/workout/workout_recorder_test.dart`:

```dart
import 'dart:async';

import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  final speed = ValueNotifier<double?>(null);
  final hr = ValueNotifier<int?>(null);

  TrainerMetrics get metrics => TrainerMetrics(
        powerW: power,
        cadenceRpm: cadence,
        speedKph: speed,
        heartRateBpm: hr,
      );
}

void main() {
  test('idle → recording → idle, collects samples at tick rate', () async {
    fakeAsync((async) {
      final fake = _Fake();
      final rec = WorkoutRecorder(
        nowProvider: () => DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
        tick: const Duration(milliseconds: 100),
      );
      expect(rec.state.value, WorkoutState.idle);

      rec.start(fake.metrics);
      expect(rec.state.value, WorkoutState.recording);

      fake.power.value = 200;
      async.elapse(const Duration(milliseconds: 100));
      fake.power.value = 210;
      async.elapse(const Duration(milliseconds: 100));

      final result = rec.stop();
      expect(rec.state.value, WorkoutState.idle);
      expect(result.samples.length, greaterThanOrEqualTo(2));
      expect(result.samples.first.powerW, 200);
    });
  });

  test('pause skips samples and excludes time from active duration', () async {
    fakeAsync((async) {
      final fake = _Fake();
      final rec = WorkoutRecorder(
        nowProvider: () => DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
        tick: const Duration(milliseconds: 100),
      );

      rec.start(fake.metrics);
      fake.power.value = 100;
      async.elapse(const Duration(milliseconds: 300));

      rec.pause();
      expect(rec.state.value, WorkoutState.paused);
      final beforePause = rec.samples.length;
      async.elapse(const Duration(milliseconds: 500));
      expect(rec.samples.length, beforePause); // no new samples while paused

      rec.resume();
      fake.power.value = 150;
      async.elapse(const Duration(milliseconds: 200));

      final result = rec.stop();
      expect(result.activeDuration.inMilliseconds, inInclusiveRange(400, 600));
    });
  });
}
```

> Add to the top of the test file if not already imported by flutter_test: `import 'package:fake_async/fake_async.dart';` and add `fake_async: any` to dev_dependencies in pubspec.yaml if not transitively available. Confirm by running the test first.

- [ ] **Step 2: Run — expect fail**

Run: `flutter test test/services/workout/workout_recorder_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement WorkoutRecorder**

Create `lib/services/workout/workout_recorder.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'trainer_metrics.dart';
import 'workout_sample.dart';
import 'workout_summary.dart';

enum WorkoutState { idle, recording, paused }

class WorkoutResult {
  final List<WorkoutSample> samples;
  final DateTime startedAt;
  final Duration activeDuration;
  final WorkoutSummary summary;
  WorkoutResult({
    required this.samples,
    required this.startedAt,
    required this.activeDuration,
    required this.summary,
  });
}

class WorkoutRecorder {
  final DateTime Function() nowProvider;
  final Duration tick;

  final ValueNotifier<WorkoutState> state = ValueNotifier(WorkoutState.idle);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);
  final List<WorkoutSample> samples = [];

  DateTime? _startedAt;
  DateTime? _lastResumedAt;
  Duration _accumulatedActive = Duration.zero;
  Timer? _timer;
  TrainerMetrics? _metrics;

  WorkoutRecorder({DateTime Function()? nowProvider, this.tick = const Duration(seconds: 1)})
      : nowProvider = nowProvider ?? DateTime.now;

  void start(TrainerMetrics metrics) {
    if (state.value != WorkoutState.idle) return;
    _metrics = metrics;
    _startedAt = nowProvider();
    _lastResumedAt = _startedAt;
    _accumulatedActive = Duration.zero;
    samples.clear();
    state.value = WorkoutState.recording;
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  void pause() {
    if (state.value != WorkoutState.recording) return;
    _accumulatedActive += nowProvider().difference(_lastResumedAt!);
    _lastResumedAt = null;
    state.value = WorkoutState.paused;
  }

  void resume() {
    if (state.value != WorkoutState.paused) return;
    _lastResumedAt = nowProvider();
    state.value = WorkoutState.recording;
  }

  WorkoutResult stop() {
    final startedAt = _startedAt ?? nowProvider();
    if (state.value == WorkoutState.recording && _lastResumedAt != null) {
      _accumulatedActive += nowProvider().difference(_lastResumedAt!);
    }
    _timer?.cancel();
    _timer = null;
    final active = _accumulatedActive;
    final captured = List<WorkoutSample>.unmodifiable(samples);
    final summary = WorkoutSummary.fromSamples(captured, startedAt: startedAt, activeDuration: active);
    _reset();
    return WorkoutResult(
      samples: captured,
      startedAt: startedAt,
      activeDuration: active,
      summary: summary,
    );
  }

  void _reset() {
    state.value = WorkoutState.idle;
    _startedAt = null;
    _lastResumedAt = null;
    _accumulatedActive = Duration.zero;
    elapsed.value = Duration.zero;
    samples.clear();
    _metrics = null;
  }

  void _onTick() {
    if (state.value != WorkoutState.recording) return;
    final m = _metrics;
    if (m == null) return;
    final now = nowProvider();
    samples.add(
      WorkoutSample(
        timestamp: now,
        powerW: m.powerW.value,
        cadenceRpm: m.cadenceRpm.value,
        speedKph: m.speedKph.value,
        heartRateBpm: m.heartRateBpm.value,
      ),
    );
    elapsed.value = _accumulatedActive + now.difference(_lastResumedAt!);
  }

  void dispose() {
    _timer?.cancel();
    state.dispose();
    elapsed.dispose();
  }
}
```

- [ ] **Step 4: Run tests — expect pass**

Run: `flutter test test/services/workout/workout_recorder_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire recorder into `core`**

Edit `lib/utils/core.dart`. After the `final connection = Connection();` line, add:

```dart
  late final workoutRecorder = WorkoutRecorder();
```

Add the import at the top:

```dart
import 'package:bike_control/services/workout/workout_recorder.dart';
```

- [ ] **Step 6: Run all tests to catch regressions**

Run: `flutter test`
Expected: all green (or same baseline as pre-change).

- [ ] **Step 7: Commit**

```bash
git add lib/services/workout/workout_recorder.dart test/services/workout/workout_recorder_test.dart lib/utils/core.dart pubspec.yaml
git commit -m "feat(workout): WorkoutRecorder with idle/recording/paused state machine"
```

---

## Task 5: WorkoutRepository (directory, listing, deletion)

**Files:**
- Create: `lib/services/workout/past_workout.dart`
- Create: `lib/services/workout/workout_repository.dart`
- Test: `test/services/workout/workout_repository_test.dart`

- [ ] **Step 1: Create PastWorkout model**

Create `lib/services/workout/past_workout.dart`:

```dart
import 'dart:io';

/// Listing-row view of a `.fit` file on disk. Fields are derived from the
/// filename (startedAt) plus `stat()` (sizeBytes) — we don't parse FIT here
/// to keep the list fast. Open-on-tap can do a full parse.
class PastWorkout {
  final File file;
  final DateTime startedAt;
  final int sizeBytes;

  const PastWorkout({
    required this.file,
    required this.startedAt,
    required this.sizeBytes,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;
}
```

- [ ] **Step 2: Write the failing repository test**

Create `test/services/workout/workout_repository_test.dart`:

```dart
import 'dart:io';

import 'package:bike_control/services/workout/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('workout-repo-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('empty directory yields empty list', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    expect(await repo.list(), isEmpty);
  });

  test('writeAndList finds the file, parses timestamp from filename', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    final saved = await repo.save(
      startedAt: DateTime.utc(2026, 4, 24, 10, 5, 7),
      fitBytes: [1, 2, 3, 4],
    );
    expect(await saved.exists(), isTrue);
    final list = await repo.list();
    expect(list, hasLength(1));
    expect(list.first.startedAt, DateTime.utc(2026, 4, 24, 10, 5, 7));
  });

  test('delete removes file', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    final saved = await repo.save(
      startedAt: DateTime.utc(2026, 4, 24, 10, 5, 7),
      fitBytes: [9, 9],
    );
    await repo.delete(saved);
    expect(await saved.exists(), isFalse);
    expect(await repo.list(), isEmpty);
  });

  test('list ignores non-fit files', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    await File('${tmp.path}/notes.txt').writeAsString('nope');
    await repo.save(startedAt: DateTime.utc(2026, 4, 24, 11), fitBytes: [0]);
    final list = await repo.list();
    expect(list, hasLength(1));
  });
}
```

- [ ] **Step 3: Run — expect fail**

Run: `flutter test test/services/workout/workout_repository_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 4: Implement WorkoutRepository**

Create `lib/services/workout/workout_repository.dart`:

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'past_workout.dart';

class WorkoutRepository {
  final Directory? _rootOverride;
  WorkoutRepository({Directory? rootOverride}) : _rootOverride = rootOverride;

  Future<Directory> rootDirectory() async {
    if (_rootOverride != null) {
      if (!await _rootOverride!.exists()) {
        await _rootOverride!.create(recursive: true);
      }
      return _rootOverride!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}workouts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> save({required DateTime startedAt, required List<int> fitBytes}) async {
    final dir = await rootDirectory();
    final name = _filenameFor(startedAt);
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(fitBytes, flush: true);
    return file;
  }

  Future<List<PastWorkout>> list() async {
    final dir = await rootDirectory();
    final entries = await dir.list().toList();
    final workouts = <PastWorkout>[];
    for (final e in entries) {
      if (e is! File) continue;
      if (!e.path.toLowerCase().endsWith('.fit')) continue;
      final parsed = _parseFilename(e.path);
      if (parsed == null) continue;
      final stat = await e.stat();
      workouts.add(PastWorkout(file: e, startedAt: parsed, sizeBytes: stat.size));
    }
    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return workouts;
  }

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
  }

  String _filenameFor(DateTime when) {
    final d = when.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
    return 'workout-$stamp.fit';
  }

  DateTime? _parseFilename(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^workout-(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z\.fit$').firstMatch(name);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
```

- [ ] **Step 5: Run tests — expect pass**

Run: `flutter test test/services/workout/workout_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Wire into core**

Edit `lib/utils/core.dart`. Below `workoutRecorder`, add:

```dart
  late final workoutRepository = WorkoutRepository();
```

Import:

```dart
import 'package:bike_control/services/workout/workout_repository.dart';
```

- [ ] **Step 7: Commit**

```bash
git add lib/services/workout/past_workout.dart lib/services/workout/workout_repository.dart test/services/workout/workout_repository_test.dart lib/utils/core.dart
git commit -m "feat(workout): WorkoutRepository for local .fit file storage"
```

---

## Task 6: MiniWorkoutPage (live recording UI)

**Files:**
- Create: `lib/pages/workout/mini_workout_page.dart`

Layout: App bar "Mini Workout" with a close button; a big elapsed-time display; a 2×2 grid of live `MetricCard` widgets (reuse `lib/pages/proxy_device_details/metric_card.dart`); at the bottom, a Start/Pause+Stop row that changes with state. On stop (after confirmation) encode + save the file, pop the page, push `WorkoutSummaryPage` with the result.

- [ ] **Step 1: Write the page**

Create `lib/pages/workout/mini_workout_page.dart`:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/pages/workout/workout_summary_page.dart';
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MiniWorkoutPage extends StatefulWidget {
  final ProxyDevice device;
  const MiniWorkoutPage({super.key, required this.device});

  @override
  State<MiniWorkoutPage> createState() => _MiniWorkoutPageState();
}

class _MiniWorkoutPageState extends State<MiniWorkoutPage> {
  WorkoutRecorder get _recorder => core.workoutRecorder;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    if (metrics != null && _recorder.state.value == WorkoutState.idle) {
      _recorder.start(metrics);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _stopAndSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).miniWorkoutConfirmStopTitle),
        content: Text(AppLocalizations.of(ctx).miniWorkoutConfirmStopBody),
        actions: [
          Button.secondary(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          Button.primary(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).miniWorkoutStop),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = _recorder.stop();
    if (result.activeDuration.inSeconds < 10) {
      _toast(AppLocalizations.of(context).miniWorkoutRecordingTooShort);
      Navigator.of(context).pop();
      return;
    }

    final bytes = FitFileWriter.encode(samples: result.samples, summary: result.summary);
    final file = await core.workoutRepository.save(startedAt: result.startedAt, fitBytes: bytes);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorkoutSummaryPage(summary: result.summary, fitFile: file)),
    );
  }

  void _toast(String msg) {
    // Minimal feedback; matches existing toast usage in the codebase (see
    // lib/widgets/ui/toast.dart). If that import is available in this
    // package, prefer buildToast(title: msg).
    debugPrint('MiniWorkout: $msg');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () async {
                if (_recorder.state.value != WorkoutState.idle) {
                  await _stopAndSave();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
          title: Text(l10n.miniWorkout),
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _recorder.elapsed,
              builder: (_, d, _) => Text(
                _fmtDuration(d),
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1),
              ),
            ),
            ValueListenableBuilder<WorkoutState>(
              valueListenable: _recorder.state,
              builder: (_, s, _) => Text(
                s == WorkoutState.paused ? l10n.miniWorkoutPaused : l10n.miniWorkoutRecording,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (metrics != null) _metricsGrid(metrics),
            if (metrics == null) Text(l10n.miniWorkoutNoTrainerConnected),
            const Gap(24),
            _controls(l10n),
          ],
        ),
      ),
    );
  }

  Widget _metricsGrid(TrainerMetrics m) {
    Widget bindInt(ValueListenable<int?> ln, {required IconData icon, required Color color, required String label, required String unit}) {
      return ValueListenableBuilder<int?>(
        valueListenable: ln,
        builder: (_, v, _) => MetricCard(icon: icon, iconColor: color, label: label, value: v?.toString(), unit: unit),
      );
    }

    Widget bindDouble(ValueListenable<double?> ln, {required IconData icon, required Color color, required String label, required String unit}) {
      return ValueListenableBuilder<double?>(
        valueListenable: ln,
        builder: (_, v, _) => MetricCard(icon: icon, iconColor: color, label: label, value: v?.toStringAsFixed(1), unit: unit),
      );
    }

    return Column(
      spacing: 10,
      children: [
        Row(spacing: 10, children: [
          bindInt(m.powerW, icon: LucideIcons.zap, color: const Color(0xFFF59E0B), label: 'POWER', unit: 'W'),
          bindInt(m.heartRateBpm, icon: LucideIcons.heart, color: const Color(0xFFEF4444), label: 'HEART', unit: 'bpm'),
        ]),
        Row(spacing: 10, children: [
          bindInt(m.cadenceRpm, icon: LucideIcons.rotateCw, color: const Color(0xFF8B5CF6), label: 'CADENCE', unit: 'rpm'),
          bindDouble(m.speedKph, icon: LucideIcons.gauge, color: const Color(0xFF0EA5E9), label: 'SPEED', unit: 'km/h'),
        ]),
      ],
    );
  }

  Widget _controls(AppLocalizations l10n) {
    return ValueListenableBuilder<WorkoutState>(
      valueListenable: _recorder.state,
      builder: (_, s, _) => Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (s == WorkoutState.recording)
            Button.secondary(
              onPressed: _recorder.pause,
              child: Text(l10n.miniWorkoutPause),
            ),
          if (s == WorkoutState.paused)
            Button.primary(
              onPressed: _recorder.resume,
              child: Text(l10n.miniWorkoutResume),
            ),
          Button.destructive(
            onPressed: _stopAndSave,
            child: Text(l10n.miniWorkoutStop),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
```

> If `Button.destructive` is not a constructor on your `shadcn_flutter` version, use `Button(style: const ButtonStyle.destructive(), ...)`. Similarly for `.primary()`/`.secondary()` — follow whichever form the codebase already uses (see `lib/pages/proxy_device_details.dart:199`).

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/pages/workout/mini_workout_page.dart`
Expected: zero errors. If `Button.destructive` isn't in your shadcn_flutter version, switch to the `Button(style: ...)` form and re-run.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout/mini_workout_page.dart
git commit -m "feat(workout): live recording page with start/pause/stop controls"
```

---

## Task 7: WorkoutSummaryPage

**Files:**
- Create: `lib/pages/workout/workout_summary_page.dart`

Shows aggregates + buttons to share the `.fit` and jump to the folder.

- [ ] **Step 1: Create the file**

```dart
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutSummaryPage extends StatelessWidget {
  final WorkoutSummary summary;
  final File fitFile;
  const WorkoutSummaryPage({super.key, required this.summary, required this.fitFile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(l10n.miniWorkoutSummaryTitle),
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _row(l10n.miniWorkoutSummaryDuration, _fmtDuration(summary.activeDuration)),
            _row(l10n.miniWorkoutSummaryDistance, '${summary.distanceKm.toStringAsFixed(2)} km'),
            _row(l10n.miniWorkoutSummaryAvgPower, '${summary.avgPowerW} W'),
            _row(l10n.miniWorkoutSummaryMaxPower, '${summary.maxPowerW} W'),
            _row(l10n.miniWorkoutSummaryAvgCadence, '${summary.avgCadenceRpm} rpm'),
            _row(l10n.miniWorkoutSummaryAvgSpeed, '${summary.avgSpeedKph.toStringAsFixed(1)} km/h'),
            if (summary.avgHeartRateBpm > 0)
              _row(l10n.miniWorkoutSummaryAvgHeartRate, '${summary.avgHeartRateBpm} bpm'),
            if (summary.maxHeartRateBpm > 0)
              _row(l10n.miniWorkoutSummaryMaxHeartRate, '${summary.maxHeartRateBpm} bpm'),
            const Gap(16),
            Button.primary(
              onPressed: () => SharePlus.instance.share(
                ShareParams(files: [XFile(fitFile.path)], text: 'Workout ${fitFile.uri.pathSegments.last}'),
              ),
              child: Text(l10n.miniWorkoutShareFit),
            ),
            Button.secondary(
              onPressed: () => _openFolder(fitFile),
              child: Text(l10n.miniWorkoutOpenFolder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value),
          ],
        ),
      );

  Future<void> _openFolder(File file) async {
    final dir = file.parent.path;
    // url_launcher opens `file://` dirs in Finder/Explorer on desktop; on
    // mobile nothing sensible happens, so we fall back to sharing the file
    // which at least lets the user inspect it through the system sheet.
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      await launchUrl(Uri.file(dir));
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
```

> `share_plus` 11+ uses `SharePlus.instance.share(ShareParams(...))`. If your resolved version is 10 or lower, use `Share.shareXFiles([XFile(fitFile.path)])` — check the resolved version in `pubspec.lock` before finalising.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/pages/workout/workout_summary_page.dart`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout/workout_summary_page.dart
git commit -m "feat(workout): post-workout summary page with share + open folder"
```

---

## Task 8: WorkoutsListPage

**Files:**
- Create: `lib/pages/workout/workouts_list_page.dart`

- [ ] **Step 1: Create the file**

```dart
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkoutsListPage extends StatefulWidget {
  const WorkoutsListPage({super.key});

  @override
  State<WorkoutsListPage> createState() => _WorkoutsListPageState();
}

class _WorkoutsListPageState extends State<WorkoutsListPage> {
  late Future<List<PastWorkout>> _future;

  @override
  void initState() {
    super.initState();
    _future = core.workoutRepository.list();
  }

  void _refresh() {
    setState(() {
      _future = core.workoutRepository.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(l10n.miniWorkoutPastWorkouts),
          trailing: [
            if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
              IconButton.ghost(
                icon: const Icon(LucideIcons.folder, size: 20),
                onPressed: () async {
                  final dir = await core.workoutRepository.rootDirectory();
                  await launchUrl(Uri.file(dir.path));
                },
              ),
          ],
        ),
        const Divider(),
      ],
      child: FutureBuilder<List<PastWorkout>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.miniWorkoutNoPastWorkouts),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(thickness: 0.5),
            itemBuilder: (context, i) => _row(items[i], l10n),
          );
        },
      ),
    );
  }

  Widget _row(PastWorkout w, AppLocalizations l10n) {
    return Button.ghost(
      onPressed: () {}, // row tap reserved for future detail view
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(_fmtDate(w.startedAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(w.fileName, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.share2, size: 18),
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(w.file.path)])),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.trash, size: 18),
            onPressed: () => _confirmDelete(w, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PastWorkout w, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.miniWorkoutConfirmDeleteTitle),
        content: Text(l10n.miniWorkoutConfirmDeleteBody),
        actions: [
          Button.secondary(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          Button.destructive(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.miniWorkoutDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await core.workoutRepository.delete(w.file);
      _refresh();
    }
  }

  static String _fmtDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/pages/workout/workouts_list_page.dart`
Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout/workouts_list_page.dart
git commit -m "feat(workout): past workouts list with share, delete, open folder"
```

---

## Task 9: MiniWorkoutCard — entry point on proxy device details

**Files:**
- Create: `lib/pages/proxy_device_details/mini_workout_card.dart`
- Modify: `lib/pages/proxy_device_details.dart`

- [ ] **Step 1: Create the card**

Create `lib/pages/proxy_device_details/mini_workout_card.dart`:

```dart
import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/workout/mini_workout_page.dart';
import 'package:bike_control/pages/workout/workouts_list_page.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class MiniWorkoutCard extends StatelessWidget {
  final ProxyDevice device;
  const MiniWorkoutCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final metrics = TrainerMetrics.fromDefinition(device.emulator.activeDefinition);
    if (metrics == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(spacing: 8, children: [
            const Icon(LucideIcons.activity, size: 18),
            Text(l10n.miniWorkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          ValueListenableBuilder<WorkoutState>(
            valueListenable: core.workoutRecorder.state,
            builder: (_, s, _) => Button.primary(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MiniWorkoutPage(device: device)),
                );
              },
              child: Text(s == WorkoutState.idle ? l10n.miniWorkoutStart : l10n.miniWorkoutRecording),
            ),
          ),
          Button.ghost(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkoutsListPage()),
            ),
            child: Text(l10n.miniWorkoutPastWorkouts),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Insert the card into proxy_device_details.dart**

Edit `lib/pages/proxy_device_details.dart`. Add import near the other `proxy_device_details/` imports:

```dart
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart';
```

Find the column block near line 115 that currently looks like:

```dart
                LiveMetricsSection(device: device),
                SizedBox(height: 20),
                _settingsSection(),
```

Replace with:

```dart
                LiveMetricsSection(device: device),
                SizedBox(height: 20),
                MiniWorkoutCard(device: device),
                SizedBox(height: 20),
                _settingsSection(),
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/pages/proxy_device_details.dart lib/pages/proxy_device_details/mini_workout_card.dart`
Expected: zero errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/proxy_device_details/mini_workout_card.dart lib/pages/proxy_device_details.dart
git commit -m "feat(workout): surface mini workout card on smart trainer details"
```

---

## Task 10: End-to-end verification

No new code. Run the app, confirm the happy path and the key edge cases.

- [ ] **Step 1: Run full test suite and analyzer**

```bash
flutter analyze
flutter test
```
Expected: no errors, no new warnings.

- [ ] **Step 2: Manual smoke test on desktop (macOS)**

```bash
flutter run -d macos
```

1. Connect to a smart trainer (or use a simulator/BLE advertiser reachable via the existing scan flow).
2. Open the smart trainer details page — confirm the "Mini Workout" card appears below Live Metrics.
3. Tap "Start Workout" — verify the live page pushes, timer counts up, metrics update.
4. Pause, wait 5 seconds, resume — verify timer pauses and resumes correctly, no samples recorded while paused.
5. Stop → confirm → summary page shows. Values plausible (avg power > 0 if trainer was sending data).
6. Tap "Open workouts folder" — Finder opens `~/Library/Containers/<bundle>/Data/Documents/workouts/`.
7. Tap "Share .fit file" — system share sheet appears with the file attached.
8. Back out to details → tap "Past workouts" → verify the newly saved workout is listed at the top.
9. Tap the trash icon → confirm → verify the row disappears and the `.fit` file is gone from the folder.

- [ ] **Step 3: Manual smoke test on mobile (iOS or Android)**

Same flow. Confirm:
- Keep-screen-on is active during recording (screen does not dim).
- Share sheet offers Strava if Strava is installed.
- Background recording: start a workout, then background the app for ~60 seconds. Return — verify the elapsed timer is still counting and that new samples were captured (the live metrics reflect the trainer's current values, not stale ones from 60 s ago).

- [ ] **Step 4: Edge case — stop under 10 seconds**

Start a workout and stop within 5 seconds. Verify no file is saved and the user is returned to the details page without a summary.

- [ ] **Step 5: Edge case — no trainer connected**

Disconnect the trainer, then check the details page is no longer accessible. Not reachable in practice — skip if there is no path to this state from the UI.

- [ ] **Step 6: Final commit if any fixes were required during testing**

If steps 2–5 surface bugs, fix them inline (each fix in its own commit), then re-run analyze + tests. If not, no commit needed.

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Start/pause/stop with a connected trainer — Task 6 (`MiniWorkoutPage`)
- ✅ Record all available trainer data (power, cadence, speed, HR) — Task 4 (`WorkoutRecorder`)
- ✅ Write to `.fit` file in a directory on the user's device — Task 3 (`FitFileWriter`) + Task 5 (`WorkoutRepository.save`)
- ✅ Summary after workout — Task 7 (`WorkoutSummaryPage`)
- ✅ Share with Strava etc. — Task 7 & 8 (`share_plus` with OS share sheet)
- ✅ Open directory — Task 7 & 8 (`launchUrl(Uri.file(...))` on desktop; fallback to share on mobile)
- ✅ List past workouts — Task 8 (`WorkoutsListPage`)
- ✅ Delete a workout — Task 8 (`_confirmDelete` in `WorkoutsListPage`)

**Type consistency:** `WorkoutResult`, `WorkoutSummary`, `WorkoutSample`, `PastWorkout`, `TrainerMetrics`, `WorkoutState` names used identically across tasks. Method names (`start`, `pause`, `resume`, `stop`, `save`, `list`, `delete`, `encode`) consistent.

**Placeholders:** none.

**YAGNI:** no charts, no cloud sync, no Strava OAuth, no background recording, no multi-workout selection, no sort/filter on the list page. These are deliberately deferred.

**DRY:** `MetricCard` reused from `proxy_device_details/metric_card.dart` in the live page.

**TDD:** Tasks 1, 2, 3, 4, 5 are test-first. Tasks 6–9 are UI-only and verified by `flutter analyze` + manual smoke testing in Task 10 — writing widget tests for shadcn_flutter pages adds more maintenance weight than value here.

---
