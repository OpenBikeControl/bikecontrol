import 'package:bike_control/services/overlay/ios_overlay_controller.dart';
import 'package:bike_control/services/overlay/ios_pip_controller.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/alert_config.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// On iOS the Live Activity IS the gear overlay: it is the only place a rider
/// sees BikeControl's virtual gear, because trainer apps can't display it.
///
/// ActivityKit caps how many Live Activities one target may hold, and an
/// activity BikeControl abandons (app force-quit mid-ride, engine restarted,
/// activity swiped away) keeps its slot until the phone reboots. Once the cap
/// is full every `Activity.request` throws `targetMaximumExceeded` — which is
/// exactly what a rider's diagnostics showed four times in a minute while
/// MyWhoosh flapped its connection, with the gear readout dead throughout.
/// So: reuse the activity iOS already has, and reap the rest.

/// Stands in for ActivityKit. [cap] is the per-target limit; [live] is what the
/// system actually holds, which is not always what it reports (see
/// [hideNextQuery] — `Activity.activities` reads empty for a beat after a cold
/// start).
class _FakeLiveActivities extends LiveActivities {
  _FakeLiveActivities({this.cap = 5});

  final int cap;
  final Map<String, LiveActivityState> live = {};

  int creates = 0;
  int updates = 0;
  final List<String> ended = [];
  int endAllCalls = 0;
  bool hideNextQuery = false;
  bool blockCreates = false;
  int _nextId = 0;

  void seed(int count, LiveActivityState state) {
    for (var i = 0; i < count; i++) {
      live['orphan-${_nextId++}'] = state;
    }
  }

  @override
  Future<void> init({
    required String appGroupId,
    String? urlScheme,
    bool requestAndroidNotificationPermission = true,
  }) async {}

  @override
  Future<Map<String, LiveActivityState>> getAllActivities() async {
    if (hideNextQuery) {
      hideNextQuery = false;
      return {};
    }
    return Map.of(live);
  }

  @override
  Future<String?> createActivity(
    String activityId,
    Map<String, dynamic> data, {
    String? activityTag,
    bool removeWhenAppIsKilled = false,
    bool iOSEnableRemoteUpdates = true,
    Duration? staleIn,
  }) async {
    creates++;
    if (blockCreates || live.length >= cap) {
      throw PlatformException(
        code: 'LIVE_ACTIVITY_ERROR',
        message: "can't launch live activity",
        details: "The operation couldn't be completed. "
            'Maximum number of activities for target already exists',
      );
    }
    final id = 'activity-${_nextId++}';
    live[id] = LiveActivityState.active;
    return id;
  }

  @override
  Future<void> updateActivity(
    String activityId,
    Map<String, dynamic> data, {
    String? activityTag,
    AlertConfig? alertConfig,
  }) async {
    final state = live[activityId];
    if (state != LiveActivityState.active && state != LiveActivityState.stale) {
      throw PlatformException(code: 'ACTIVITY_ERROR', message: 'Activity not found');
    }
    updates++;
    live[activityId] = LiveActivityState.active;
  }

  @override
  Future<void> endActivity(String activityId, {String? activityTag}) async {
    ended.add(activityId);
    live.remove(activityId);
  }

  @override
  Future<void> endAllActivities() async {
    endAllCalls++;
    live.clear();
  }
}

/// PiP is a separate native window and irrelevant here; keeping it off also
/// keeps the test off the `bike_control/pip_ios` MethodChannel.
class _NoPip implements IosPipController {
  @override
  Future<bool> isSupported() async => false;
  @override
  Future<bool> isCapable() async => false;
  @override
  Future<void> start(Map<String, dynamic> state) async {}
  @override
  Future<void> update(Map<String, dynamic> state) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  FitnessBikeDefinition makeDefinition() {
    final scanResult = BleDevice(
      deviceId: 'kickr',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    );
    return FitnessBikeDefinition(
      connectedDevice: scanResult,
      connectedDeviceServices: [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])],
      data: ValueNotifier(''),
    );
  }

  Future<void> showOn(IosOverlayController controller) async {
    await controller.show(makeDefinition(), {OverlayField.power});
  }

  group('planLiveActivity', () {
    test('reuses the activity this session started', () {
      final plan = planLiveActivity(
        trackedId: 'mine',
        existing: const {'mine': LiveActivityState.active},
      );

      expect(plan.adopt, 'mine');
      expect(plan.end, isEmpty);
    });

    // The tracked id is memory-only, so it is null on every fresh launch —
    // which is precisely when the previous launch's activity is still sitting
    // there holding a slot.
    test('adopts an activity left behind by an earlier launch', () {
      final plan = planLiveActivity(
        trackedId: null,
        existing: const {'from-yesterday': LiveActivityState.active},
      );

      expect(plan.adopt, 'from-yesterday');
      expect(plan.end, isEmpty);
    });

    test('a stale activity is adopted — the update we are about to push fixes it', () {
      final plan = planLiveActivity(
        trackedId: null,
        existing: const {'old-content': LiveActivityState.stale},
      );

      expect(plan.adopt, 'old-content');
    });

    // An ended activity is still on screen and still counted, but can never be
    // updated again, so the only useful thing to do with it is reap it.
    test('ended and dismissed activities are reaped, not adopted', () {
      final plan = planLiveActivity(
        trackedId: null,
        existing: const {
          'finished': LiveActivityState.ended,
          'gone': LiveActivityState.dismissed,
        },
      );

      expect(plan.adopt, isNull);
      expect(plan.end, ['finished', 'gone']);
    });

    test('keeps one activity and ends every other one', () {
      final plan = planLiveActivity(
        trackedId: 'mine',
        existing: const {
          'orphan-a': LiveActivityState.active,
          'mine': LiveActivityState.active,
          'orphan-b': LiveActivityState.ended,
        },
      );

      expect(plan.adopt, 'mine');
      expect(plan.end, ['orphan-a', 'orphan-b']);
    });
  });

  group('IosOverlayController.show', () {
    test('showing twice updates the same activity instead of requesting another', () async {
      final la = _FakeLiveActivities();
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      await showOn(controller);
      await showOn(controller);

      expect(la.creates, 1);
      expect(la.live, hasLength(1));
      expect(la.updates, greaterThanOrEqualTo(1));
      expect(controller.isShowing.value, isTrue);
    });

    // The reported crash: the cap was already full of activities from previous
    // rides, so every request threw and the rider's gear display stayed dead.
    test('a target already full of orphans is swept, then started', () async {
      final la = _FakeLiveActivities(cap: 3)..seed(3, LiveActivityState.ended);
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      await showOn(controller);

      expect(la.ended, hasLength(3));
      expect(la.live, hasLength(1));
      expect(controller.isShowing.value, isTrue);
    });

    // `Activity.activities` reads empty for a beat after a cold start, so the
    // sweep can come back with nothing while the slots are still taken.
    test('recovers when iOS under-reports what it is holding', () async {
      final la = _FakeLiveActivities(cap: 2)
        ..seed(2, LiveActivityState.active)
        ..hideNextQuery = true;
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      await showOn(controller);

      expect(la.endAllCalls, 1);
      expect(la.creates, 2, reason: 'the first request throws, the retry after the sweep succeeds');
      expect(la.live, hasLength(1));
      expect(controller.isShowing.value, isTrue);
    });

    // A flapping trainer-app connection re-enters show() while the first one is
    // still awaiting ActivityKit.
    test('overlapping show() calls collapse into one request', () async {
      final la = _FakeLiveActivities();
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      final first = controller.show(makeDefinition(), {OverlayField.power});
      final second = controller.show(makeDefinition(), {OverlayField.power});
      await Future.wait([first, second]);

      expect(la.creates, 1);
      expect(la.live, hasLength(1));
    });

    // Both requests failing means there is no gear readout — the Overlay switch
    // and the auto-show guard both read isShowing, so it has to say so.
    test('a show that cannot start anything does not claim to be showing', () async {
      final la = _FakeLiveActivities();
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      await showOn(controller);
      expect(controller.isShowing.value, isTrue);

      la.live.clear();
      la.blockCreates = true;
      final result = await controller.show(makeDefinition(), {OverlayField.power});

      expect(result.ok, isFalse);
      expect(controller.isShowing.value, isFalse);
    });

    test('hide ends the activity, and a later show starts a fresh one', () async {
      final la = _FakeLiveActivities();
      final controller = IosOverlayController(liveActivities: la, pip: _NoPip());

      await showOn(controller);
      await controller.hide();
      expect(la.live, isEmpty);
      expect(controller.isShowing.value, isFalse);

      await showOn(controller);
      expect(la.creates, 2);
      expect(la.live, hasLength(1));
    });
  });
}
