import 'package:bike_control/pages/home/chain_inputs.dart';
import 'package:bike_control/pages/home/chain_state.dart';

/// Turns [ChainInputs] into the cards the home screen renders, in signal-path
/// order: your buttons → the gears BikeControl computes → the app that
/// receives them.
///
/// Pure: same inputs, same cards. Every "is this step done" rule in the app
/// lives here and nowhere else, so the banner, the card headers and the
/// checklists can never disagree.
List<ChainLink> buildChain(ChainInputs inputs) {
  return [
    ..._controllerLinks(inputs),
    // A sensors link only takes the trainer's slot in sensors-only mode. A
    // trainer input, when present, always wins: the home page is the one
    // that enforces exiting sensors-only mode once a trainer shows up, but
    // the builder stays safe even if it is ever called with both set.
    if (inputs.trainer == null && inputs.sensors != null) _sensorsLink(inputs) else _trainerLink(inputs),
    _appLink(inputs),
  ];
}

/// A device is only truly here when it is [DevicePresence.connected]. A
/// resetting device counts as connected for step purposes — it is mid-reboot,
/// not mid-failure — but its card still shows amber.
bool _isPresent(DevicePresence presence) => presence == DevicePresence.connected;

/// Maps presence onto the status of a link whose setup is otherwise complete.
LinkStatus _presenceStatus(DevicePresence presence) => switch (presence) {
  DevicePresence.connected => LinkStatus.ready,
  DevicePresence.resetting => LinkStatus.attention,
  DevicePresence.lost => LinkStatus.problem,
  DevicePresence.remembered => LinkStatus.attention,
  // Never connected is "not set up", not "something broke".
  DevicePresence.discovered => LinkStatus.off,
};

List<ChainLink> _controllerLinks(ChainInputs inputs) {
  if (inputs.controllers.isEmpty) {
    // Nothing paired ever: one placeholder card that reads as an invitation
    // rather than a fault. "Paired" and "mapped" are the two things a fresh
    // rider has to do, and neither is done.
    return [
      ChainLink(
        key: ChainLinkKey.controller,
        id: 'controller',
        status: LinkStatus.off,
        title: '',
        steps: [
          SetupStep(id: SetupStepId.controllerBluetoothReady, done: inputs.bluetoothReady),
          const SetupStep(id: SetupStepId.controllerPaired, done: false),
          const SetupStep(id: SetupStepId.controllerButtonsMapped, done: false),
        ],
      ),
    ];
  }

  return inputs.controllers.map((controller) {
    final inRange = _isPresent(controller.presence);
    final guidedSetupDone = controller.sramSetupDone;
    // A Click V2 waiting for its unlock-mode choice gets that one step and
    // nothing else. It is discovered and in range; the app is choosing not to
    // connect it, so "pair it" and "bring it back in range" would both be
    // false, and neither is what the rider has to do.
    final steps = controller.needsUnlockModeChoice
        ? <SetupStep>[
            if (controller.requiresBluetooth)
              SetupStep(id: SetupStepId.controllerBluetoothReady, done: inputs.bluetoothReady),
            const SetupStep(id: SetupStepId.controllerClickV2Setup, done: false),
          ]
        : <SetupStep>[
            if (controller.requiresBluetooth)
              SetupStep(id: SetupStepId.controllerBluetoothReady, done: inputs.bluetoothReady),
            // Pairing is history: once done it stays ticked even while the device is
            // away. A device we have merely discovered has no such history yet.
            SetupStep(
              id: SetupStepId.controllerPaired,
              done: controller.presence != DevicePresence.discovered,
            ),
            // Ahead of mapping, because it is what produces the buttons to map: a
            // derailleur whose own shifting is still enabled sends nothing at all, so
            // "assign an action to a button" is advice the rider cannot act on yet.
            //
            // Emitted when it is ticked — history, like pairing, and it survives the
            // device walking away — or when the device is here to run it. Listing it
            // for one out of range would offer a sheet that writes over a connection
            // there isn't, and bury the only thing that helps, "bring it back in
            // range", underneath it.
            if (guidedSetupDone != null && (guidedSetupDone || inRange))
              SetupStep(id: SetupStepId.controllerSramSetup, done: guidedSetupDone),
            // Only once there are buttons to map. A derailleur declares none
            // until its paddles have been heard from, so the line would name
            // work with nothing to work on — see [ControllerInput.hasKnownButtons].
            if (controller.hasKnownButtons || controller.hasMappedButtons)
              SetupStep(id: SetupStepId.controllerButtonsMapped, done: controller.hasMappedButtons),
            SetupStep(id: SetupStepId.controllerInRange, done: inRange),
            // Last, because unlocking needs the controller present. Omitted entirely
            // for anything that has no such concept — see [ControllerInput.unlocked].
            if (controller.unlocked != null)
              SetupStep(
                id: SetupStepId.controllerUnlocked,
                done: controller.unlocked!,
                hintArg: controller.unlockedUntil,
                uncertain: controller.unlockUncertain,
              ),
            // An offer, not work: once the derailleur's config has been updated
            // its own shifting is off, and the rider can hand it back at any
            // time. After the required steps so it never outranks a genuine one,
            // and only while the derailleur is in range — restore talks to it
            // over BLE, so an out-of-range line could not act. It clears the
            // backup when it runs, so it can never sit ticked: like the
            // keep-awake offer, it is only ever emitted while outstanding.
            if (controller.sramCanRestore && inRange)
              const SetupStep(id: SetupStepId.controllerSramRestore, done: false, optional: true),
            // An offer, not work: the right puck stays on with or without a
            // left one, which only keeps its lights lit. Only emitted while
            // outstanding, so it never sits ticked on a card forever.
            if (controller.clickV2NeedsLeftSide)
              const SetupStep(
                id: SetupStepId.controllerClickV2KeepAwake,
                done: false,
                optional: true,
              ),
          ];

    // An unfinished checklist outranks a healthy connection: a connected
    // controller with no buttons mapped does nothing, so it must not be green.
    // Optional steps are offers and stay out of it — see [SetupStep.optional].
    final incomplete = steps.any((s) => !s.done && !s.optional);
    final presenceStatus = _presenceStatus(controller.presence);
    final status = incomplete && presenceStatus == LinkStatus.ready ? LinkStatus.attention : presenceStatus;

    return ChainLink(
      key: ChainLinkKey.controller,
      id: 'controller:${controller.deviceId}',
      status: status,
      title: controller.name,
      steps: steps,
      deviceId: controller.deviceId,
      // Only an absent device may be swiped away. Dismissing a live controller
      // would be a destructive accident, so the gesture simply isn't there.
      dismissible: !inRange && controller.presence != DevicePresence.resetting,
    );
  }).toList();
}

ChainLink _trainerLink(ChainInputs inputs) {
  final trainer = inputs.trainer;
  if (trainer == null) {
    // No trainer has ever been paired. The card stays as an empty, dashed,
    // explicitly optional slot — no checklist, because there is nothing the
    // rider must do here to be ready to ride.
    return const ChainLink(
      key: ChainLinkKey.trainer,
      id: 'trainer',
      status: LinkStatus.off,
      title: '',
      optional: true,
      steps: [],
    );
  }

  final paired = _isPresent(trainer.presence);
  // A checklist only earns its space once the rider has committed to bridging
  // this trainer. Before that — a trainer merely in range, or one deliberately
  // left on "let the app handle shifting" — a list of unticked boxes reads as
  // work outstanding when nothing is outstanding at all.
  final committed =
      trainer.presence != DevicePresence.discovered && trainer.presence != DevicePresence.remembered;
  // The two facts onboarding checks, in its order: the bridge is running, and
  // the trainer app has picked the virtual trainer up. Gear ratios are a
  // preference with a working default, not a step — a rider is never blocked
  // waiting to "set up gears".
  final steps = committed
      ? <SetupStep>[
          SetupStep(id: SetupStepId.trainerPaired, done: paired),
          SetupStep(
            id: SetupStepId.trainerAppBridged,
            done: trainer.appHoldsBridge,
            hintArg: trainer.bridgeName,
          ),
          // Last, and required until answered: the trainer app shows its own
          // gear, not the one BikeControl computes, so a bridged rider who has
          // not turned the overlay on is looking at a number that will disagree
          // with their shifter. That is the single most common support
          // question, and it outlived a toast *and* an optional line on this
          // card — so the step now blocks "Ready to ride" until the rider
          // either turns the overlay on or says "not now". A decline takes the
          // step off the card entirely (a greyed-out offer would still read as
          // unfinished) until the overlay is switched on somewhere, which
          // clears it. Only offered once the bridge is up: before that there
          // is no gear.
          if (paired && trainer.overlayOffered && (trainer.overlayEnabled || !trainer.overlayDeclined))
            SetupStep(id: SetupStepId.trainerGearOverlay, done: trainer.overlayEnabled),
        ]
      : const <SetupStep>[];

  final incomplete = steps.any((s) => !s.done && !s.optional);
  // An uncommitted trainer — in range but never bridged, or deliberately left
  // to the app — rests at "off". Amber would be wrong twice: it isn't waiting
  // on anything, and on an optional card amber blocks "Ready to ride".
  final presenceStatus = committed ? _presenceStatus(trainer.presence) : LinkStatus.off;
  final status = incomplete && presenceStatus == LinkStatus.ready ? LinkStatus.attention : presenceStatus;

  return ChainLink(
    key: ChainLinkKey.trainer,
    id: 'trainer',
    status: status,
    title: trainer.name,
    optional: true,
    steps: steps,
    // Live numbers are shown whenever the trainer is reporting them — they
    // come off the trainer, not off the bridge, so withholding them until the
    // whole link is green would hide something true and useful.
    subtitleArg: trainer.metrics,
    deviceId: trainer.deviceId,
    dismissible: !paired && trainer.presence != DevicePresence.resetting,
  );
}

/// Sensors-only mode's trainer-slot card: no bridge to set up, no checklist —
/// just whether the broadcast is actually live.
ChainLink _sensorsLink(ChainInputs inputs) {
  final sensors = inputs.sensors!;
  return ChainLink(
    key: ChainLinkKey.sensors,
    id: 'sensors',
    status: sensors.broadcasting ? LinkStatus.ready : LinkStatus.off,
    title: sensors.sourceNames.isEmpty ? '' : sensors.sourceNames.first,
    optional: true,
    steps: const [],
  );
}

ChainLink _appLink(ChainInputs inputs) {
  final app = inputs.app;
  final selected = app.name != null;
  // A self-hosted app (BikeControl running the workout itself) has no wire to
  // check: both connection steps are satisfied by definition.
  final hasMethod = app.selfHosted || app.hasEnabledConnection;
  final connected = app.selfHosted || app.isConnected;

  final steps = <SetupStep>[
    SetupStep(id: SetupStepId.appSelected, done: selected),
    SetupStep(id: SetupStepId.appConnectionMethod, done: selected && hasMethod),
    // Between the method and the wire, because that is where it bites: the
    // bridge is switched on and looks fine, but without the permission nothing
    // it advertises ever leaves the device. Required, not optional — a rider
    // cannot ride past this one.
    if (selected && app.localNetworkGranted != null)
      SetupStep(id: SetupStepId.appLocalNetwork, done: app.localNetworkGranted!),
    SetupStep(id: SetupStepId.appConnected, done: selected && connected),
    // Last, and optional: Local is not a way to reach the app, it is a way to
    // do *more* to it — keystrokes and clicks the button editor only offers
    // once it is on. Nobody has to have it, so it never colours the card; but
    // a rider who never turns it on never finds out those actions exist.
    // Named after an app because the copy does: there is nothing to control
    // until one is chosen.
    if (selected && app.localControlOffered)
      SetupStep(
        id: SetupStepId.appLocalControl,
        done: app.localControlEnabled,
        optional: true,
      ),
  ];

  final LinkStatus status;
  if (steps.every((s) => s.done || s.optional)) {
    status = LinkStatus.ready;
  } else if (!selected) {
    status = LinkStatus.off;
  } else if (app.wasConnectedThisSession && !app.isConnected) {
    // It was carrying commands a moment ago and stopped — that is a break, not
    // an unfinished setup.
    status = LinkStatus.problem;
  } else {
    status = LinkStatus.attention;
  }

  return ChainLink(
    key: ChainLinkKey.app,
    id: 'app',
    status: status,
    title: app.name ?? '',
    steps: steps,
    subtitleArg: status == LinkStatus.ready ? app.connectionSummary : null,
  );
}
