import 'package:bike_control/pages/home/chain_builder.dart';
import 'package:bike_control/pages/home/chain_inputs.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

const _readyApp = AppInput(
  name: 'MyWhoosh',
  hasEnabledConnection: true,
  isConnected: true,
  wasConnectedThisSession: true,
  connectionSummary: 'Network',
);

ControllerInput controller({
  String deviceId = 'aa:bb',
  String name = 'Zwift Click V2',
  DevicePresence presence = DevicePresence.connected,
  bool hasMappedButtons = true,
  bool hasKnownButtons = true,
  bool requiresBluetooth = true,
  bool? unlocked,
  String? unlockedUntil,
  bool unlockUncertain = false,
  bool? sramSetupDone,
  bool sramCanRestore = false,
  bool needsUnlockModeChoice = false,
  bool clickV2NeedsLeftSide = false,
}) {
  return ControllerInput(
    deviceId: deviceId,
    name: name,
    presence: presence,
    hasMappedButtons: hasMappedButtons,
    hasKnownButtons: hasKnownButtons,
    requiresBluetooth: requiresBluetooth,
    unlocked: unlocked,
    unlockedUntil: unlockedUntil,
    unlockUncertain: unlockUncertain,
    sramSetupDone: sramSetupDone,
    sramCanRestore: sramCanRestore,
    needsUnlockModeChoice: needsUnlockModeChoice,
    clickV2NeedsLeftSide: clickV2NeedsLeftSide,
  );
}

TrainerInput trainer({
  DevicePresence presence = DevicePresence.connected,
  bool appHoldsBridge = true,
  String? metrics = '250 W · 90 rpm',
  bool overlayOffered = false,
  bool overlayEnabled = false,
  bool overlayAnswered = false,
  bool overlayDeclined = false,
  String? rawTrainerName,
}) {
  return TrainerInput(
    deviceId: 'trainer-1',
    name: 'Wahoo KICKR CORE',
    presence: presence,
    appHoldsBridge: appHoldsBridge,
    bridgeName: 'KICKR CORE - BikeControl',
    rawTrainerName: rawTrainerName,
    metrics: metrics,
    overlayOffered: overlayOffered,
    overlayEnabled: overlayEnabled,
    overlayAnswered: overlayAnswered,
    overlayDeclined: overlayDeclined,
  );
}

SensorsInput sensors({
  List<String> sourceNames = const ['Heart Rate Monitor'],
  bool broadcasting = true,
  RetrofitMode transport = RetrofitMode.bluetooth,
  String? clientName,
}) {
  return SensorsInput(
    sourceNames: sourceNames,
    broadcasting: broadcasting,
    transport: transport,
    clientName: clientName,
  );
}

extension on List<ChainLink> {
  ChainLink byKey(ChainLinkKey key) => firstWhere((l) => l.key == key);
  Iterable<ChainLink> allOf(ChainLinkKey key) => where((l) => l.key == key);
}

bool _stepDone(ChainLink link, SetupStepId id) => link.steps.firstWhere((s) => s.id == id).done;

bool _hasStep(ChainLink link, SetupStepId id) => link.steps.any((s) => s.id == id);

void main() {
  group('chain shape', () {
    test('renders controller, trainer then app in signal-path order', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], trainer: trainer(), app: _readyApp));
      expect(chain.map((l) => l.key), [ChainLinkKey.controller, ChainLinkKey.trainer, ChainLinkKey.app]);
    });

    test('renders one card per controller, each with its own id', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(deviceId: 'left'), controller(deviceId: 'right')],
          app: _readyApp,
        ),
      );
      final controllers = chain.allOf(ChainLinkKey.controller).toList();
      expect(controllers, hasLength(2));
      expect(controllers.map((l) => l.id), ['controller:left', 'controller:right']);
    });
  });

  group('controller steps', () {
    test('a connected, mapped controller is ready with every step done', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.ready);
      expect(link.remainingSteps, 0);
      expect(link.activeStepIndex, isNull);
      expect(_stepDone(link, SetupStepId.controllerInRange), isTrue);
    });

    // Zwift locks the Click V2 to their own app and it stops sending presses a
    // minute later, which is indistinguishable from a flat battery unless the
    // chain says so. Every other controller must not grow a line it can never
    // tick.
    test('a locked controller carries an outstanding unlock step', () {
      final chain = buildChain(ChainInputs(controllers: [controller(unlocked: false)], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerUnlocked), isFalse);
      // And it is the thing to do next: everything before it is already done.
      expect(link.activeStep?.id, SetupStepId.controllerUnlocked);
      // A card with work outstanding is never green.
      expect(link.status, LinkStatus.attention);
    });

    test('an unlocked controller ticks the step and stays ready', () {
      final chain = buildChain(ChainInputs(controllers: [controller(unlocked: true)], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerUnlocked), isTrue);
      expect(link.remainingSteps, 0);
      expect(link.status, LinkStatus.ready);
    });

    // Deliberately the one done step that carries detail: an unlock expires, so
    // a bare tick would hide that it comes back tomorrow.
    test('a finished unlock step carries its deadline and its certainty', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(unlocked: true, unlockedUntil: 'Friday, 14:30', unlockUncertain: true)],
          app: _readyApp,
        ),
      );
      final step = chain.byKey(ChainLinkKey.controller).steps.firstWhere(
        (s) => s.id == SetupStepId.controllerUnlocked,
      );
      expect(step.done, isTrue);
      expect(step.hintArg, 'Friday, 14:30');
      // BikeControl cannot read the lock state back, so "unlocked" is a guess
      // and the label has to say so.
      expect(step.uncertain, isTrue);
    });

    test('a confirmed unlock is not marked uncertain', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(unlocked: true, unlockedUntil: 'Friday, 14:30')],
          app: _readyApp,
        ),
      );
      final step = chain.byKey(ChainLinkKey.controller).steps.firstWhere(
        (s) => s.id == SetupStepId.controllerUnlocked,
      );
      expect(step.uncertain, isFalse);
    });

    // A SRAM derailleur whose own shifting is still enabled is connected and
    // sends nothing at all — the card used to show that as a bare empty panel.
    test('a SRAM derailleur awaiting its guided setup carries that step', () {
      final chain = buildChain(ChainInputs(controllers: [controller(sramSetupDone: false)], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerSramSetup), isFalse);
      expect(link.activeStep?.id, SetupStepId.controllerSramSetup);
      expect(link.status, LinkStatus.attention);
    });

    // The real fresh case, and the one the default hasMappedButtons: true hid:
    // the guided setup is what PRODUCES the buttons, so "map your buttons"
    // must not jump ahead of it.
    test('guided setup outranks mapping on a derailleur with no buttons yet', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: false, hasMappedButtons: false)],
          app: _readyApp,
        ),
      );
      expect(chain.byKey(ChainLinkKey.controller).activeStep?.id, SetupStepId.controllerSramSetup);
    });

    test('a finished SRAM setup ticks and leaves the card ready', () {
      final chain = buildChain(ChainInputs(controllers: [controller(sramSetupDone: true)], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerSramSetup), isTrue);
      expect(link.remainingSteps, 0);
      expect(link.status, LinkStatus.ready);
    });

    // It outranks the unlock step: a derailleur that sends nothing cannot be
    // helped by anything further down the list.
    test('guided setup comes before the unlock step', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(sramSetupDone: false, unlocked: false)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.activeStep?.id, SetupStepId.controllerSramSetup);
    });

    // Reported: an out-of-range derailleur listed "Set up SRAM control" and
    // "Map your buttons" above "Bring it back in range", and the card's
    // instructions button opened the guided sheet — which writes to a
    // derailleur BikeControl has no connection to.
    test('an absent derailleur is asked to come back, not to run its setup', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [
            controller(
              presence: DevicePresence.remembered,
              sramSetupDone: false,
              hasKnownButtons: false,
              hasMappedButtons: false,
            ),
          ],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerSramSetup), isFalse);
      expect(_hasStep(link, SetupStepId.controllerButtonsMapped), isFalse);
      expect(link.activeStep?.id, SetupStepId.controllerInRange);
      expect(link.remainingSteps, 1);
    });

    test('a finished guided setup stays ticked while the derailleur is away', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(presence: DevicePresence.remembered, sramSetupDone: true)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerSramSetup), isTrue);
      expect(link.activeStep?.id, SetupStepId.controllerInRange);
    });

    // A derailleur declares no buttons of its own: they are learned from the
    // presses it sends, which only start once the guided setup has run. Until
    // then the keymap has nothing to assign an action to.
    test('a controller with no buttons discovered yet is not asked to map them', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: false, hasKnownButtons: false, hasMappedButtons: false)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerButtonsMapped), isFalse);
      expect(link.activeStep?.id, SetupStepId.controllerSramSetup);
    });

    // Reported edge case: a brand-new install where the wizard was skipped or
    // finished on another controller, then a Click V2 is switched on. It is
    // discovered and in range, and BikeControl is deliberately not connecting
    // it — so the card claimed "never paired" and "bring it back in range"
    // about a controller sitting switched on beside the rider.
    test('a Click V2 awaiting its unlock-mode choice shows only that step', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [
            controller(
              presence: DevicePresence.discovered,
              hasMappedButtons: false,
              needsUnlockModeChoice: true,
            ),
          ],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.activeStep?.id, SetupStepId.controllerClickV2Setup);
      // The misleading ones are gone, not merely outranked.
      expect(link.steps.any((s) => s.id == SetupStepId.controllerPaired), isFalse);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerInRange), isFalse);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerButtonsMapped), isFalse);
    });

    test('once the choice is made the normal checklist returns', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.discovered)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerClickV2Setup), isFalse);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerPaired), isTrue);
    });

    test('a controller with no guided setup has no such step', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerSramSetup), isFalse);
    });

    // Once a SRAM derailleur's config has been updated (its own shifting
    // disabled, a backup captured) the rider can hand the gears back — an offer,
    // not work, so it lives on the card as an optional line rather than a toast.
    test('offers restore when the config was updated and a backup is on hand', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: true, sramCanRestore: true)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.controllerSramRestore);
      expect(step.optional, isTrue, reason: 'restoring is an offer, not something the rider must do');
      expect(step.done, isFalse);
    });

    test('the restore offer never colours the card or blocks riding', () {
      // Same regression the keep-awake offer guards: an undone optional step
      // must not turn a working, mapped controller amber or hold back riding.
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: true, sramCanRestore: true)],
          trainer: trainer(),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.ready);
      expect(link.steps.where((s) => !s.done && !s.optional), isEmpty);
    });

    test('no restore offer when there is nothing to restore', () {
      // Setup done but no backup to put back — offering restore would be a dead
      // button.
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: true, sramCanRestore: false)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerSramRestore), isFalse);
    });

    test('the restore offer is withheld while the derailleur is out of range', () {
      // Restore talks to the derailleur over BLE, so an out-of-range one would
      // show a line that cannot act — mirror the setup step, which is likewise
      // presence-gated.
      final chain = buildChain(
        ChainInputs(
          controllers: [
            controller(presence: DevicePresence.remembered, sramSetupDone: true, sramCanRestore: true),
          ],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerSramRestore), isFalse);
    });

    test('a real outstanding step still outranks the restore offer', () {
      // The optional offer must not mask a genuine one sitting beside it.
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(sramSetupDone: true, sramCanRestore: true, hasMappedButtons: false)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.attention);
      expect(link.activeStep?.id, SetupStepId.controllerButtonsMapped);
    });

    test('offers the keep-awake step when a right puck has no left one in range', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(clickV2NeedsLeftSide: true)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.controllerClickV2KeepAwake);
      expect(step.optional, isTrue, reason: 'the controller works without it; it is an offer, not work');
      expect(step.done, isFalse);
    });

    test('the keep-awake offer is absent once it is no longer outstanding', () {
      // Emitted only while waiting, so it never sits ticked on the card forever.
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerClickV2KeepAwake), isFalse);
    });

    test('the keep-awake offer never colours the card or blocks riding', () {
      // The regression this guards: the controller link used to count every
      // undone step, optional or not, so this offer alone turned a working
      // controller amber and held back "Ready to ride".
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(clickV2NeedsLeftSide: true)],
          trainer: trainer(),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.ready);
      expect(link.steps.where((s) => !s.done && !s.optional), isEmpty);
    });

    test('a real outstanding step still outranks the optional offer', () {
      // The optional step must not mask a genuine one sitting beside it.
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(hasMappedButtons: false, clickV2NeedsLeftSide: true)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.attention);
      expect(link.activeStep?.id, SetupStepId.controllerButtonsMapped);
    });

    test('a controller with no unlock concept has no unlock step at all', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.steps.any((s) => s.id == SetupStepId.controllerUnlocked), isFalse);
    });

    test('pairing stays ticked while the device is away — it is history', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.remembered)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerPaired), isTrue);
      expect(_stepDone(link, SetupStepId.controllerInRange), isFalse);
    });

    test('a remembered controller is amber, not red, on a fresh launch', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.remembered)], app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.controller).status, LinkStatus.attention);
    });

    test('a controller that dropped this session is red', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.lost)], app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.controller).status, LinkStatus.problem);
    });

    test('a controller we have only discovered has not been paired yet', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.discovered)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_stepDone(link, SetupStepId.controllerPaired), isFalse);
      expect(link.status, LinkStatus.off);
    });

    test('a resetting controller is amber and never red', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.resetting)], app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.controller).status, LinkStatus.attention);
    });

    test('a connected controller with no buttons mapped is not green', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(hasMappedButtons: false)], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.status, LinkStatus.attention);
      expect(link.activeStep!.id, SetupStepId.controllerButtonsMapped);
    });

    test('Bluetooth being off leaves the first step as the active one', () {
      final chain = buildChain(
        ChainInputs(bluetoothReady: false, controllers: [controller()], app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(link.activeStep!.id, SetupStepId.controllerBluetoothReady);
      expect(link.status, LinkStatus.attention);
    });

    test('a non-Bluetooth controller has no Bluetooth step at all', () {
      final chain = buildChain(
        ChainInputs(
          bluetoothReady: false,
          controllers: [controller(requiresBluetooth: false)],
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.controller);
      expect(_hasStep(link, SetupStepId.controllerBluetoothReady), isFalse);
      expect(link.status, LinkStatus.ready);
    });

    test('no controller at all renders one grey placeholder, not an empty screen', () {
      final chain = buildChain(const ChainInputs(app: _readyApp));
      final controllers = chain.allOf(ChainLinkKey.controller).toList();
      expect(controllers, hasLength(1));
      expect(controllers.single.status, LinkStatus.off);
      expect(controllers.single.id, 'controller');
      expect(controllers.single.deviceId, isNull);
      expect(_stepDone(controllers.single, SetupStepId.controllerPaired), isFalse);
    });
  });

  group('swipe-away eligibility', () {
    test('a connected controller cannot be swiped away', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      expect(chain.byKey(ChainLinkKey.controller).dismissible, isFalse);
    });

    test('remembered and lost controllers can be swiped away', () {
      for (final presence in [DevicePresence.remembered, DevicePresence.lost]) {
        final chain = buildChain(
          ChainInputs(controllers: [controller(presence: presence)], app: _readyApp),
        );
        expect(chain.byKey(ChainLinkKey.controller).dismissible, isTrue, reason: presence.name);
      }
    });

    test('a resetting controller cannot be swiped away — it is coming back', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller(presence: DevicePresence.resetting)], app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.controller).dismissible, isFalse);
    });

    test('the placeholder card is not dismissible', () {
      final chain = buildChain(const ChainInputs(app: _readyApp));
      expect(chain.byKey(ChainLinkKey.controller).dismissible, isFalse);
    });
  });

  group('trainer link', () {
    test('is optional and, with no trainer known, has no checklist', () {
      final chain = buildChain(const ChainInputs(app: _readyApp));
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.optional, isTrue);
      expect(link.status, LinkStatus.off);
      expect(link.steps, isEmpty);
      expect(link.isBlocking, isFalse);
    });

    test('a trainer we have only discovered offers no checklist', () {
      final chain = buildChain(
        ChainInputs(trainer: trainer(presence: DevicePresence.discovered), app: _readyApp),
      );
      // Unticked boxes on a trainer nobody has committed to read as work
      // outstanding when there is none.
      expect(chain.byKey(ChainLinkKey.trainer).steps, isEmpty);
    });

    test('a remembered trainer left disconnected offers no checklist either', () {
      final chain = buildChain(
        ChainInputs(trainer: trainer(presence: DevicePresence.remembered), app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.trainer).steps, isEmpty);
    });

    test('a trainer that dropped keeps its checklist', () {
      final chain = buildChain(ChainInputs(trainer: trainer(presence: DevicePresence.lost), app: _readyApp));
      expect(chain.byKey(ChainLinkKey.trainer).steps, isNotEmpty);
    });

    test('a connected trainer with gears set up is ready and shows its metrics', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], trainer: trainer(), app: _readyApp));
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.status, LinkStatus.ready);
      expect(link.subtitleArg, '250 W · 90 rpm');
    });

    // The numbers come off the trainer, not off the bridge: a trainer that is
    // reporting watts is reporting watts whether or not the app has picked the
    // bridge up, and hiding them until the whole link is green would withhold
    // something both true and useful.
    test('live values show even while the app has not picked the bridge up', () {
      final chain = buildChain(ChainInputs(trainer: trainer(appHoldsBridge: false), app: _readyApp));
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.status, LinkStatus.attention);
      expect(link.subtitleArg, '250 W · 90 rpm');
    });

    test('a trainer reporting nothing shows no readout', () {
      final chain = buildChain(
        ChainInputs(trainer: trainer(presence: DevicePresence.remembered, metrics: null), app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.trainer).subtitleArg, isNull);
    });

    // The bug this pins down: a trainer the scanner had only just found was
    // reported as having lost a connection it never had.
    // Regression: a remembered trainer mapped to amber, which on an optional
    // card blocks "Ready to ride" — and made the card present itself as
    // bridged when it was not even in the room.
    test('a remembered trainer rests at off and does not block the rider', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(presence: DevicePresence.remembered, appHoldsBridge: false),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.status, LinkStatus.off);
      expect(link.isBlocking, isFalse);
      expect(deriveBanner(chain).kind, ChainBannerKind.ready);
    });

    test('a trainer we have only discovered is not reported as broken', () {
      final chain = buildChain(
        ChainInputs(trainer: trainer(presence: DevicePresence.discovered), app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.status, isNot(LinkStatus.problem));
      expect(link.status, LinkStatus.off);
    });

    test('a newly discovered trainer does not stop the rider being ready', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(presence: DevicePresence.discovered),
          app: _readyApp,
        ),
      );
      expect(chain.byKey(ChainLinkKey.trainer).isBlocking, isFalse);
      expect(deriveBanner(chain).kind, ChainBannerKind.ready);
    });

    test('a trainer that actually dropped is still reported as broken', () {
      final chain = buildChain(ChainInputs(trainer: trainer(presence: DevicePresence.lost), app: _readyApp));
      expect(chain.byKey(ChainLinkKey.trainer).status, LinkStatus.problem);
    });

    // Onboarding is the source of truth: a bridge the trainer app hasn't picked
    // up yet is honest about it rather than claiming to be bridged.
    test('a bridged trainer the app has not picked up is amber, not ready', () {
      final chain = buildChain(ChainInputs(trainer: trainer(appHoldsBridge: false), app: _readyApp));
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.status, LinkStatus.attention);
      expect(link.activeStep!.id, SetupStepId.trainerAppBridged);
    });

    test('the pick-up step names the bridge to look for', () {
      final chain = buildChain(ChainInputs(trainer: trainer(), app: _readyApp));
      final step = chain.byKey(ChainLinkKey.trainer).steps.firstWhere((s) => s.id == SetupStepId.trainerAppBridged);
      expect(step.hintArg, 'KICKR CORE - BikeControl');
    });

    // The trainer app lists the trainer twice: once under its own name and
    // once as the bridge. Riders pick the first, which bypasses BikeControl
    // entirely — so the step carries the wrong entry as well as the right one.
    test("the pick-up step also names the entry under the trainer's own name", () {
      final chain = buildChain(ChainInputs(trainer: trainer(rawTrainerName: 'KICKR CORE 1234'), app: _readyApp));
      final step = chain.byKey(ChainLinkKey.trainer).steps.firstWhere((s) => s.id == SetupStepId.trainerAppBridged);
      expect(step.hintArg, 'KICKR CORE - BikeControl');
      expect(step.secondaryHintArg, 'KICKR CORE 1234');
    });

    test('an unknown trainer name leaves the entry to avoid out', () {
      final chain = buildChain(ChainInputs(trainer: trainer(), app: _readyApp));
      final step = chain.byKey(ChainLinkKey.trainer).steps.firstWhere((s) => s.id == SetupStepId.trainerAppBridged);
      expect(step.secondaryHintArg, isNull);
    });

    test('gear ratios are a preference, never a setup step', () {
      final chain = buildChain(ChainInputs(trainer: trainer(), app: _readyApp));
      expect(
        chain.byKey(ChainLinkKey.trainer).steps.map((s) => s.id),
        [SetupStepId.trainerPaired, SetupStepId.trainerAppBridged],
      );
    });
  });

  group('sensors link', () {
    test('sensors-only mode replaces the trainer link with a sensors link', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], sensors: sensors(), app: _readyApp));
      expect(chain.map((l) => l.key), [ChainLinkKey.controller, ChainLinkKey.sensors, ChainLinkKey.app]);
      expect(chain.any((l) => l.key == ChainLinkKey.trainer), isFalse);
    });

    test('is optional with no checklist', () {
      final chain = buildChain(ChainInputs(sensors: sensors(), app: _readyApp));
      final link = chain.byKey(ChainLinkKey.sensors);
      expect(link.optional, isTrue);
      expect(link.steps, isEmpty);
      expect(link.isBlocking, isFalse);
    });

    test('is ready while broadcasting', () {
      final chain = buildChain(ChainInputs(sensors: sensors(broadcasting: true), app: _readyApp));
      expect(chain.byKey(ChainLinkKey.sensors).status, LinkStatus.ready);
    });

    test('is off while not broadcasting', () {
      final chain = buildChain(ChainInputs(sensors: sensors(broadcasting: false), app: _readyApp));
      expect(chain.byKey(ChainLinkKey.sensors).status, LinkStatus.off);
    });

    test('titles itself after the first source', () {
      final chain = buildChain(
        ChainInputs(sensors: sensors(sourceNames: const ['Power Meter', 'Cadence Sensor']), app: _readyApp),
      );
      expect(chain.byKey(ChainLinkKey.sensors).title, 'Power Meter');
    });

    test('titles itself blank with no sources', () {
      final chain = buildChain(ChainInputs(sensors: sensors(sourceNames: const []), app: _readyApp));
      expect(chain.byKey(ChainLinkKey.sensors).title, '');
    });

    // A trainer showing up is how a rider leaves sensors-only mode. The home
    // page is what actually drops the sensors input when that happens, but
    // the builder has to be safe even if it is ever called with both set.
    test('a trainer input present alongside sensors makes the trainer link win', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller()], trainer: trainer(), sensors: sensors(), app: _readyApp),
      );
      expect(chain.map((l) => l.key), [ChainLinkKey.controller, ChainLinkKey.trainer, ChainLinkKey.app]);
      expect(chain.any((l) => l.key == ChainLinkKey.sensors), isFalse);
    });
  });

  // The trainer app draws its own gear, not the one BikeControl computes, so a
  // bridged rider without the overlay is looking at a number that disagrees
  // with their shifter — the single most common support question. It was a
  // toast, then an optional line on the card, and riders walked past both
  // (most of the chats came from a build that already showed the line). So
  // it is now a step the rider has to answer once — turn the overlay on, or
  // say "not now" — the way the Local Network step is required, whose chats
  // fell away the day it started gating. Once answered it is never required
  // again: an overlay switched off later is an offer, as it was before.
  group('the gear overlay step', () {
    test('a bridged trainer that can show the overlay asks for an answer', () {
      final chain = buildChain(
        ChainInputs(controllers: [controller()], trainer: trainer(overlayOffered: true), app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.trainerGearOverlay);
      expect(step.done, isFalse);
      expect(step.optional, isFalse);
      // Last, so it never displaces the work that actually blocks the rider.
      expect(link.steps.last.id, SetupStepId.trainerGearOverlay);
      // Required: the card goes amber and the banner counts it, exactly like
      // any other unfinished step.
      expect(link.status, LinkStatus.attention);
      expect(link.isBlocking, isTrue);
      expect(link.remainingSteps, 1);
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.pending);
      expect(banner.stepsLeft, 1);
      expect(banner.targetKey, ChainLinkKey.trainer);
    });

    // "Not now" is a real answer: the step leaves the card entirely rather
    // than lingering as a greyed-out offer, and the rider is ready to ride.
    test('a declined overlay takes the step off the card and lets the rider ride', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(overlayOffered: true, overlayAnswered: true, overlayDeclined: true),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(_hasStep(link, SetupStepId.trainerGearOverlay), isFalse);
      expect(link.status, LinkStatus.ready);
      expect(link.isBlocking, isFalse);
      expect(deriveBanner(chain).kind, ChainBannerKind.ready);
    });

    test('ticks off once the rider has turned the overlay on', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(overlayOffered: true, overlayEnabled: true, overlayAnswered: true),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(_stepDone(link, SetupStepId.trainerGearOverlay), isTrue);
      expect(link.status, LinkStatus.ready);
      // Done steps leave the checklist, so the card is back to its header.
      expect(link.pendingSteps, isEmpty);
    });

    // The regression the review caught: an overlay the rider had on and then
    // switched off — the trainer page's switch, or the Live Activity's "stop
    // ride" on every ride end — must not put the amber card and "1 step left"
    // back. They have answered; from here on the line is an offer again.
    test('an overlay switched off after being answered is an optional offer', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(overlayOffered: true, overlayAnswered: true),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.trainerGearOverlay);
      expect(step.done, isFalse);
      expect(step.optional, isTrue);
      expect(link.status, LinkStatus.ready);
      expect(link.isBlocking, isFalse);
      expect(link.remainingSteps, 0);
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.ready);
      expect(banner.stepsLeft, 0);
    });

    // Turning the overlay on clears a decline at the settings layer, but the
    // builder must not lean on that: an overlay that is on is a ticked step
    // whatever a stale decline flag says.
    test('an enabled overlay outranks a stale decline', () {
      final chain = buildChain(
        ChainInputs(
          trainer: trainer(overlayOffered: true, overlayEnabled: true, overlayAnswered: true, overlayDeclined: true),
          app: _readyApp,
        ),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.trainerGearOverlay);
      expect(step.done, isTrue);
      expect(step.optional, isFalse);
      expect(link.status, LinkStatus.ready);
    });

    // Riding from another device, on a platform that can't draw one, or without
    // a Virtual Shifting session: all three are answered upstream, and all three
    // arrive here as "don't offer it".
    test('is absent when the overlay is not on offer', () {
      final chain = buildChain(ChainInputs(trainer: trainer(), app: _readyApp));
      expect(_hasStep(chain.byKey(ChainLinkKey.trainer), SetupStepId.trainerGearOverlay), isFalse);
    });

    // Before the bridge is up BikeControl computes no gear, so there is nothing
    // for an overlay to show and nothing to contradict.
    test('is not offered on a trainer whose bridge is down', () {
      final chain = buildChain(
        ChainInputs(
          trainer: trainer(presence: DevicePresence.lost, appHoldsBridge: false, overlayOffered: true),
          app: _readyApp,
        ),
      );
      expect(_hasStep(chain.byKey(ChainLinkKey.trainer), SetupStepId.trainerGearOverlay), isFalse);
    });

    // Ordering, stated as the thing that matters: while the app has not picked
    // the bridge up, that is still the next action — the overlay waits its turn.
    test('waits behind the pick-up step', () {
      final chain = buildChain(
        ChainInputs(trainer: trainer(appHoldsBridge: false, overlayOffered: true), app: _readyApp),
      );
      final link = chain.byKey(ChainLinkKey.trainer);
      expect(link.activeStep?.id, SetupStepId.trainerAppBridged);
      expect(link.status, LinkStatus.attention);
    });
  });

  group('app link', () {
    test('is ready when selected, wired and connected', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.status, LinkStatus.ready);
      expect(link.subtitleArg, 'Network');
    });

    test('no app selected is grey, with selection as the active step', () {
      final chain = buildChain(const ChainInputs());
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.status, LinkStatus.off);
      expect(link.activeStep!.id, SetupStepId.appSelected);
    });

    test('later steps stay pending while no app is selected', () {
      final chain = buildChain(const ChainInputs(app: AppInput(hasEnabledConnection: true, isConnected: true)));
      final link = chain.byKey(ChainLinkKey.app);
      expect(_stepDone(link, SetupStepId.appConnectionMethod), isFalse);
      expect(_stepDone(link, SetupStepId.appConnected), isFalse);
    });

    group('Local Network step', () {
      test('is absent when the permission does not apply', () {
        // Bluetooth-only, or a platform without the permission: there is
        // nothing to grant, so the rider must not be shown a step.
        final chain = buildChain(const ChainInputs(app: _readyApp));
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appLocalNetwork), isFalse);
      });

      test('ticks green once granted, rather than vanishing', () {
        final chain = buildChain(
          const ChainInputs(app: AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            isConnected: true,
            localNetworkGranted: true,
          )),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(_stepDone(link, SetupStepId.appLocalNetwork), isTrue);
        expect(link.status, LinkStatus.ready);
      });

      test('an unmeasurable permission is not an outstanding step', () {
        // localNetworkGranted carries LocalNetworkAccess.usable(), so unknown
        // arrives here as true — the rider must not be handed work on the
        // strength of a probe that could not tell.
        final chain = buildChain(
          const ChainInputs(app: AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            isConnected: true,
            localNetworkGranted: true,
          )),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(_stepDone(link, SetupStepId.appLocalNetwork), isTrue);
        expect(link.status, LinkStatus.ready);
      });

      test('is the outstanding step when denied, and holds the card back', () {
        // Required, not optional: a denied permission means the bridge cannot
        // be reached, so the card must not read as ready.
        final chain = buildChain(
          const ChainInputs(app: AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            localNetworkGranted: false,
          )),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(_stepDone(link, SetupStepId.appLocalNetwork), isFalse);
        expect(link.activeStep!.id, SetupStepId.appLocalNetwork);
        expect(link.status, isNot(LinkStatus.ready));
      });

      test('comes after the connection method and before the connection', () {
        // The permission gates the wire, so it cannot be the rider's first or
        // last piece of work on this card.
        final chain = buildChain(
          const ChainInputs(app: AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            localNetworkGranted: false,
          )),
        );
        final ids = chain.byKey(ChainLinkKey.app).steps.map((s) => s.id).toList();
        expect(ids.indexOf(SetupStepId.appLocalNetwork),
            greaterThan(ids.indexOf(SetupStepId.appConnectionMethod)));
        expect(ids.indexOf(SetupStepId.appLocalNetwork),
            lessThan(ids.indexOf(SetupStepId.appConnected)));
      });
    });

    // A VPN, a mesh network or a second adapter can leave BikeControl
    // advertising an address the trainer app cannot reach. The self-test
    // already says so — but only to a rider who has found that page. The
    // card says it first, and only while it is still the problem.
    group('network address step', () {
      test('is present and required while a flagged address is advertised and the app has not connected', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(advertisedAddressWarning: '10.5.0.2', isConnected: false, hasEnabledConnection: true),
          ),
        );
        final link = chain.byKey(ChainLinkKey.app);
        final step = link.steps.firstWhere((s) => s.id == SetupStepId.appNetworkAddress);
        expect(step.done, isFalse);
        expect(step.optional, isFalse);
        expect(step.hintArg, '10.5.0.2');
        expect(link.requiredSteps, contains(step));
        expect(link.status, isNot(LinkStatus.ready));
      });

      test('disappears once the app connects', () {
        // A connected app has reached the address, whatever it looks like —
        // the warning would contradict the tick right under it.
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(advertisedAddressWarning: '10.5.0.2', isConnected: true, hasEnabledConnection: true),
          ),
        );
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appNetworkAddress), isFalse);
      });

      test('is absent when the advertised address looks fine', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(advertisedAddressWarning: null, isConnected: false, hasEnabledConnection: true),
          ),
        );
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appNetworkAddress), isFalse);
      });

      test('is absent while no connection method is enabled', () {
        // Nothing is advertised yet, so there is no address to warn about;
        // switching a method on is the step that is actually outstanding.
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(advertisedAddressWarning: '10.5.0.2', isConnected: false, hasEnabledConnection: false),
          ),
        );
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appNetworkAddress), isFalse);
      });

      test('is absent for a self-hosted app, which has no wire to reach', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'BikeControl',
              selfHosted: true,
              advertisedAddressWarning: '10.5.0.2',
              hasEnabledConnection: true,
            ),
          ),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(_hasStep(link, SetupStepId.appNetworkAddress), isFalse);
        expect(link.status, LinkStatus.ready);
      });

      test('is the active step once the method and the permission are done, ahead of the connection', () {
        // It explains why "connected" is not happening, so it has to come
        // before that step — and after the ones it depends on.
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'MyWhoosh',
              hasEnabledConnection: true,
              localNetworkGranted: true,
              advertisedAddressWarning: '100.101.102.103',
            ),
          ),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(link.activeStep!.id, SetupStepId.appNetworkAddress);
        final ids = link.steps.map((s) => s.id).toList();
        expect(ids.indexOf(SetupStepId.appNetworkAddress), greaterThan(ids.indexOf(SetupStepId.appLocalNetwork)));
        expect(ids.indexOf(SetupStepId.appNetworkAddress), lessThan(ids.indexOf(SetupStepId.appConnected)));
      });

      // The trainer app reaches BikeControl twice — once for the trainer, once
      // for the controller — and a trainer held over the network is proof the
      // advertised address is reachable, whatever it looks like. A trainer
      // held over Bluetooth proves nothing about the network.
      test('is absent while the app already holds the trainer over the network', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'MyWhoosh',
              hasEnabledConnection: true,
              advertisedAddressWarning: '10.5.0.2',
              trainerBridgedByApp: true,
              trainerBridgedOverNetwork: true,
            ),
          ),
        );
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appNetworkAddress), isFalse);
      });

      test('stays while the app holds the trainer over Bluetooth only', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'MyWhoosh',
              hasEnabledConnection: true,
              advertisedAddressWarning: '10.5.0.2',
              trainerBridgedByApp: true,
              trainerBridgedOverNetwork: false,
            ),
          ),
        );
        final link = chain.byKey(ChainLinkKey.app);
        expect(_hasStep(link, SetupStepId.appNetworkAddress), isTrue);
        expect(link.activeStep!.id, SetupStepId.appNetworkAddress);
      });

      test('stays while the app holds no trainer at all', () {
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'MyWhoosh',
              hasEnabledConnection: true,
              advertisedAddressWarning: '10.5.0.2',
              trainerBridgedByApp: false,
              trainerBridgedOverNetwork: false,
            ),
          ),
        );
        expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appNetworkAddress), isTrue);
      });

      test('a denied Local Network permission still comes first', () {
        // Without the permission nothing leaves the device at all, so which
        // address is advertised is not yet the rider's problem.
        final chain = buildChain(
          const ChainInputs(
            app: AppInput(
              name: 'MyWhoosh',
              hasEnabledConnection: true,
              localNetworkGranted: false,
              advertisedAddressWarning: '10.5.0.2',
            ),
          ),
        );
        expect(chain.byKey(ChainLinkKey.app).activeStep!.id, SetupStepId.appLocalNetwork);
      });
    });

    test('selected but with no connection method is amber', () {
      final chain = buildChain(const ChainInputs(app: AppInput(name: 'MyWhoosh')));
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.status, LinkStatus.attention);
      expect(link.activeStep!.id, SetupStepId.appConnectionMethod);
    });

    // A trainer app that goes away after it worked has almost always just been
    // closed. Red with "Fix" sent riders into a network test with nothing to
    // find, so the card goes amber and simply says the app disconnected.
    group('an app that was connected and dropped', () {
      const dropped = AppInput(name: 'MyWhoosh', hasEnabledConnection: true, wasConnectedThisSession: true);

      test('is amber and flagged as dropped', () {
        final link = buildChain(const ChainInputs(app: dropped)).byKey(ChainLinkKey.app);
        expect(link.status, LinkStatus.attention);
        expect(link.dropped, isTrue);
      });

      test('is never red, whatever else is outstanding on the card', () {
        const apps = [
          dropped,
          // The method was switched off after the app had connected.
          AppInput(name: 'MyWhoosh', wasConnectedThisSession: true),
          AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            wasConnectedThisSession: true,
            localNetworkGranted: false,
          ),
          AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            wasConnectedThisSession: true,
            advertisedAddressWarning: '10.5.0.2',
          ),
          AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            wasConnectedThisSession: true,
            trainerBridgedByApp: true,
          ),
        ];
        for (final app in apps) {
          final link = buildChain(ChainInputs(app: app)).byKey(ChainLinkKey.app);
          expect(link.status, LinkStatus.attention, reason: '${link.activeStep}');
          expect(link.dropped, isTrue, reason: '${link.activeStep}');
        }
      });

      test('still waits on the connection step, as before', () {
        final link = buildChain(const ChainInputs(app: dropped)).byKey(ChainLinkKey.app);
        expect(link.activeStep?.id, SetupStepId.appConnected);
        expect(link.remainingSteps, 1);
      });
    });

    test('an app that has never connected is amber, not red, and not dropped', () {
      final chain = buildChain(const ChainInputs(app: AppInput(name: 'MyWhoosh', hasEnabledConnection: true)));
      expect(chain.byKey(ChainLinkKey.app).status, LinkStatus.attention);
      expect(chain.byKey(ChainLinkKey.app).dropped, isFalse);
    });

    test('a connected app is not dropped', () {
      expect(buildChain(const ChainInputs(app: _readyApp)).byKey(ChainLinkKey.app).dropped, isFalse);
    });

    // Nothing to drop: no app is picked, or BikeControl runs the workout
    // itself and there is no wire to it at all.
    test('neither an unpicked nor a self-hosted app is ever dropped', () {
      const apps = [
        AppInput(hasEnabledConnection: true, wasConnectedThisSession: true),
        AppInput(name: 'BikeControl', selfHosted: true, wasConnectedThisSession: true),
      ];
      for (final app in apps) {
        expect(buildChain(ChainInputs(app: app)).byKey(ChainLinkKey.app).dropped, isFalse, reason: app.name);
      }
    });

    test('a self-hosted app needs no connection method and is ready on selection', () {
      final chain = buildChain(const ChainInputs(app: AppInput(name: 'BikeControl', selfHosted: true)));
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.status, LinkStatus.ready);
      expect(link.remainingSteps, 0);
    });

    // The trainer app's pairing screen has two BikeControl tiles — the trainer
    // and the controller — and the most common support case is a rider who
    // paired one and not the other. Once the app is reading the trainer through
    // BikeControl, "waiting for the app to connect" is only half true, so the
    // step says which half is missing.
    group('with the trainer already picked up by the app', () {
      const app = AppInput(name: 'MyWhoosh', hasEnabledConnection: true, trainerBridgedByApp: true);

      SetupStep connectedStep(ChainInputs inputs) =>
          buildChain(inputs).byKey(ChainLinkKey.app).steps.firstWhere((s) => s.id == SetupStepId.appConnected);

      test('the connection step is flagged as the controller link being the missing one', () {
        final step = connectedStep(const ChainInputs(app: app));
        expect(step.done, isFalse);
        expect(step.variant, SetupStepVariant.controllerLinkMissing);
      });

      test('no other step on the card is flagged', () {
        final others = buildChain(
          const ChainInputs(app: app),
        ).byKey(ChainLinkKey.app).steps.where((s) => s.id != SetupStepId.appConnected);
        expect(others, isNotEmpty);
        expect(others.every((s) => s.variant == SetupStepVariant.standard), isTrue);
      });

      test('the plain connection step keeps its ordinary wording', () {
        final step = connectedStep(const ChainInputs(app: AppInput(name: 'MyWhoosh', hasEnabledConnection: true)));
        expect(step.done, isFalse);
        expect(step.variant, SetupStepVariant.standard);
      });

      test('a held bridge with no app picked flags nothing — there is no app to name', () {
        final step = connectedStep(const ChainInputs(app: AppInput(trainerBridgedByApp: true)));
        expect(step.variant, SetupStepVariant.standard);
      });
    });
  });

  // Local control is not a way to reach the trainer app, it is a way to do more
  // to it: keystrokes and clicks the button editor only offers once it is on. A
  // rider on the same device who never turns it on never learns those actions
  // exist, so the app card says so — as an offer, never as work.
  group('the local control step', () {
    const offered = AppInput(
      name: 'MyWhoosh',
      hasEnabledConnection: true,
      isConnected: true,
      wasConnectedThisSession: true,
      connectionSummary: 'Network',
      localControlOffered: true,
    );

    test('an app on this device with Local switched off offers it', () {
      final chain = buildChain(const ChainInputs(app: offered));
      final link = chain.byKey(ChainLinkKey.app);
      final step = link.steps.firstWhere((s) => s.id == SetupStepId.appLocalControl);
      expect(step.done, isFalse);
      expect(step.optional, isTrue);
      // Last, behind every step that actually blocks the rider.
      expect(link.steps.last.id, SetupStepId.appLocalControl);
    });

    // Riding from another device, or on a platform with no local control at
    // all: both are answered upstream by CoreLogic.showLocalControl.
    test('is absent when Local is not available here', () {
      final chain = buildChain(ChainInputs(app: _readyApp));
      expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appLocalControl), isFalse);
    });

    test('ticks off once Local is on', () {
      final chain = buildChain(
        const ChainInputs(
          app: AppInput(
            name: 'MyWhoosh',
            hasEnabledConnection: true,
            isConnected: true,
            localControlOffered: true,
            localControlEnabled: true,
          ),
        ),
      );
      final link = chain.byKey(ChainLinkKey.app);
      expect(_stepDone(link, SetupStepId.appLocalControl), isTrue);
      expect(link.pendingSteps, isEmpty);
    });

    // The copy names the app, and there is nothing to control before one is
    // chosen.
    test('is not offered before a trainer app is picked', () {
      final chain = buildChain(const ChainInputs(app: AppInput(localControlOffered: true)));
      expect(_hasStep(chain.byKey(ChainLinkKey.app), SetupStepId.appLocalControl), isFalse);
    });

    // The regression this guards: an offer that keeps a working app card amber
    // and holds back "Ready to ride" is not an offer.
    test('never blocks the rider or colours the card', () {
      final chain = buildChain(const ChainInputs(controllers: [], app: offered));
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.status, LinkStatus.ready);
      expect(link.isBlocking, isFalse);
      expect(link.remainingSteps, 0);
      expect(deriveBanner([link]).kind, ChainBannerKind.ready);
    });

    // While the app is still being wired up, that is the next action — the
    // offer waits its turn rather than competing with it.
    test('waits behind the connection steps', () {
      final chain = buildChain(
        const ChainInputs(app: AppInput(name: 'MyWhoosh', localControlOffered: true)),
      );
      final link = chain.byKey(ChainLinkKey.app);
      expect(link.activeStep?.id, SetupStepId.appConnectionMethod);
      expect(link.status, LinkStatus.attention);
    });
  });

  group('end to end with the banner', () {
    test('the everyday case: ready to ride', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], trainer: trainer(), app: _readyApp));
      expect(deriveBanner(chain).kind, ChainBannerKind.ready);
    });

    test('no trainer paired is still ready to ride', () {
      final chain = buildChain(ChainInputs(controllers: [controller()], app: _readyApp));
      expect(deriveBanner(chain).kind, ChainBannerKind.ready);
    });

    test('a lost controller points the banner at that exact card', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(deviceId: 'left'), controller(deviceId: 'right', presence: DevicePresence.lost)],
          app: _readyApp,
        ),
      );
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.broken);
      expect(banner.targetLinkId, 'controller:right');
    });

    test('fresh install counts every outstanding step across both cards', () {
      final chain = buildChain(const ChainInputs());
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.pending);
      // Controller placeholder: paired + mapped. App: selected + method + connected.
      expect(banner.stepsLeft, 5);
      expect(banner.targetLinkId, 'controller');
      expect(banner.outstandingKeys, [ChainLinkKey.controller, ChainLinkKey.app]);
    });

    test('a trainer app that dropped after working is pending, not broken', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          app: const AppInput(name: 'MyWhoosh', hasEnabledConnection: true, wasConnectedThisSession: true),
        ),
      );
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.pending);
      expect(banner.status, LinkStatus.attention);
      expect(banner.appDropped, isTrue);
      expect(banner.targetLinkId, 'app');
      expect(banner.stepsLeft, 1);
    });

    test('a controller that broke still leads over a trainer app that dropped', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller(presence: DevicePresence.lost)],
          app: const AppInput(name: 'MyWhoosh', hasEnabledConnection: true, wasConnectedThisSession: true),
        ),
      );
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.broken);
      expect(banner.targetKey, ChainLinkKey.controller);
      expect(banner.appDropped, isFalse);
    });

    test('a bridged trainer waiting only on the controller link hands the banner that one step', () {
      final chain = buildChain(
        ChainInputs(
          controllers: [controller()],
          trainer: trainer(),
          app: const AppInput(name: 'MyWhoosh', hasEnabledConnection: true, trainerBridgedByApp: true),
        ),
      );
      final banner = deriveBanner(chain);
      expect(banner.kind, ChainBannerKind.pending);
      expect(banner.stepsLeft, 1);
      expect(banner.soleStep?.id, SetupStepId.appConnected);
      expect(banner.soleStep?.variant, SetupStepVariant.controllerLinkMissing);
    });
  });
}
