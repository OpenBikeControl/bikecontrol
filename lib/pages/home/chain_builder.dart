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
            // The entry NOT to pick, when known: the trainer under its own
            // name sits right beside the bridge in the app's list.
            secondaryHintArg: trainer.rawTrainerName,
          ),
          // Last, and required until answered once: the trainer app shows its
          // own gear, not the one BikeControl computes, so a bridged rider who
          // has not turned the overlay on is looking at a number that will
          // disagree with their shifter. That is the single most common
          // support question, and it outlived a toast *and* an optional line
          // on this card — so the step blocks "Ready to ride" until the rider
          // either turns the overlay on or says "not now". Either answer is
          // final for the blocking: an overlay switched off afterwards (the
          // trainer page's switch, the Live Activity's "stop ride" on every
          // ride end) leaves the line as the offer it used to be, never as
          // work outstanding. A decline takes the step off the card entirely
          // (a greyed-out offer would still read as unfinished) until the
          // overlay is switched on somewhere, which clears it. Only offered
          // once the bridge is up: before that there is no gear.
          if (paired && trainer.overlayOffered && (trainer.overlayEnabled || !trainer.overlayDeclined))
            SetupStep(
              id: SetupStepId.trainerGearOverlay,
              done: trainer.overlayEnabled,
              optional: !trainer.overlayEnabled && trainer.overlayAnswered,
            ),
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
  // This very app connected earlier in this session, over a real method —
  // the page latches that per app, see [AppInput.wasConnectedThisSession].
  final connectedEarlier = selected && app.wasConnectedThisSession;

  final steps = <SetupStep>[
    SetupStep(id: SetupStepId.appSelected, done: selected),
    SetupStep(id: SetupStepId.appConnectionMethod, done: selected && hasMethod),
    // Between the method and the wire, because that is where it bites: the
    // bridge is switched on and looks fine, but without the permission nothing
    // it advertises ever leaves the device. Required, not optional — a rider
    // cannot ride past this one.
    if (selected && app.localNetworkGranted != null)
      SetupStep(id: SetupStepId.appLocalNetwork, done: app.localNetworkGranted!),
    // The address being advertised is one the app is unlikely to reach — a
    // VPN, a mesh, a hotspot, a second adapter. Only once a method is on
    // (before that nothing is advertised) and only until the app connects:
    // a connected app has reached it, whatever it looks like, and the warning
    // would contradict the tick right under it. So it is only ever emitted
    // while outstanding, and required: this is the most common reason
    // "waiting for the app" never ends, and the self-test that would say so
    // sits on a page the rider has to know to look for.
    //
    // Never while the app already holds the trainer over the network: that
    // rides on this very address, so the app has plainly reached it, and the
    // only thing left is the controller tile — which the connected step
    // below says. A trainer held over Bluetooth proves nothing here.
    //
    // Nor after the app has connected through this same verdict earlier in
    // the session: it reached the address then, whatever it looks like. Two
    // adapters on different subnets flag many a desktop for good while the
    // app connects there just fine, and a drop there is no network news.
    // Only a verdict that is new since the app connected — a VPN that came up
    // and took the app with it — brings the step back.
    if (app.hasEnabledConnection &&
        !connected &&
        !app.trainerBridgedOverNetwork &&
        app.advertisedAddressWarning != null &&
        !(connectedEarlier && app.advertisedAddressWarning == app.advertisedAddressWarningAtConnect))
      SetupStep(id: SetupStepId.appNetworkAddress, done: false, hintArg: app.advertisedAddressWarning),
    SetupStep(
      id: SetupStepId.appConnected,
      done: selected && connected,
      // Once the app is reading the trainer through BikeControl, the
      // trainer half of its pairing screen is done and only the controller
      // tile is missing — say that, not "waiting for the app". Only with an
      // app to name: the sentence is about a specific app's pairing screen.
      variant: selected && app.trainerBridgedByApp
          ? SetupStepVariant.controllerLinkMissing
          : SetupStepVariant.standard,
    ),
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

  // It was carrying commands earlier in this session and has stopped. Unlike a
  // controller or a trainer, that is not a break: a trainer app that goes
  // away has almost always just been closed, and red with "Fix" sent riders
  // into a network test that had nothing to find. So it stays amber, like any
  // other wait for the app, and the card says it disconnected — see
  // [ChainLink.dropped]. Not while it still holds the trainer: then it is
  // plainly open, only its controller tile is missing, and the connection
  // step already says exactly that. A self-hosted app has no wire to lose.
  final dropped = connectedEarlier && !connected && !app.trainerBridgedByApp;

  final LinkStatus status;
  if (steps.every((s) => s.done || s.optional)) {
    status = LinkStatus.ready;
  } else if (!selected) {
    status = LinkStatus.off;
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
    wasConnectedThisSession: connectedEarlier,
    dropped: dropped,
  );
}
