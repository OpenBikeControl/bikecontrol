/// The world the setup chain is built from, as plain data.
///
/// [ChainInputs] is the seam between the app's live state (BLE, settings, the
/// `core` singleton) and the chain's derivation logic. `HomePage` fills one in
/// from `core`; [buildChain] turns it into cards. Tests construct one directly
/// and never touch Bluetooth.
library;

import 'package:prop/emulators/dircon_emulator.dart';

/// How present a known device is right now.
///
/// The distinction between [lost] and [remembered] is the whole reason this
/// enum exists rather than a bare `isConnected` bool: a controller that
/// dropped mid-ride is a red problem, while one that simply hasn't been
/// switched on since the app started is amber. A fresh app launch with the
/// controller in a drawer must not paint the screen red.
enum DevicePresence {
  /// Connected and usable.
  connected,

  /// Rebooting because of an automatic reset — it comes back by itself, so it
  /// is never a problem.
  resetting,

  /// Was connected during this app session and dropped.
  lost,

  /// Known from a previous session, not seen yet this time.
  remembered,

  /// In range and known to the app, but never actually connected — a trainer
  /// the scanner just found, say. It has nothing to lose, so it can never be
  /// [lost]; treating it as such is how a brand-new trainer ended up shouting
  /// "lost connection" on a screen it had only just appeared on.
  discovered,
}

class ControllerInput {
  const ControllerInput({
    required this.deviceId,
    required this.name,
    required this.presence,
    required this.hasMappedButtons,
    this.hasKnownButtons = true,
    this.requiresBluetooth = true,
    this.unlocked,
    this.unlockedUntil,
    this.unlockUncertain = false,
    this.sramSetupDone,
    this.sramCanRestore = false,
    this.needsUnlockModeChoice = false,
    this.clickV2NeedsLeftSide = false,
  });

  final String deviceId;
  final String name;
  final DevicePresence presence;

  /// Whether the active keymap assigns at least one action to one of this
  /// device's buttons.
  final bool hasMappedButtons;

  /// Whether BikeControl knows which buttons this controller even has.
  ///
  /// Almost every controller declares its buttons the moment it is known, so
  /// mapping them is a keymap edit the rider can make from the sofa. A SRAM
  /// derailleur declares none: its paddles are learned from the presses they
  /// send, and those only start once the guided setup has run on a connected
  /// device. Until then "map your buttons" names work with nothing to work
  /// on — the keymap has no entry to assign an action to.
  final bool hasKnownButtons;

  /// False for controllers that don't ride on BLE (USB/OS gamepads, the
  /// phone's gyroscope). Their card omits the Bluetooth step, which would
  /// otherwise be a permanently ticked line that means nothing.
  final bool requiresBluetooth;

  /// Whether this controller is currently unlocked, or null when unlocking is
  /// not a concept for it.
  ///
  /// Only Zwift's Click V2 has this: Zwift locks it to their own app, and it
  /// stops sending button presses about a minute after the last one unless it
  /// has been unlocked. Every other controller — and a Click V2 running the
  /// restart workaround instead — passes null, so its card omits the step
  /// rather than carrying a line that can never be actioned.
  final bool? unlocked;

  /// When the current unlock runs out, preformatted for display. Null while the
  /// controller is locked, or when unlocking does not apply.
  final String? unlockedUntil;

  /// Whether [unlocked] is a best guess — see [SetupStep.uncertain].
  final bool unlockUncertain;

  /// Whether this controller's guided setup has run, or null when it has none.
  ///
  /// Today that means a SRAM AXS derailleur, whose own shifting has to be
  /// disabled before its paddles send button presses to BikeControl at all —
  /// so until it runs, the controller is connected and does nothing. Named for
  /// SRAM rather than generically because the step's wording is SRAM's; a
  /// second device with its own guided setup wants its own id, not this one
  /// silently mislabelled.
  final bool? sramSetupDone;

  /// Whether this controller can restore its original on-device shifting — a
  /// SRAM AXS derailleur whose config setup disabled has already updated, with a
  /// backup still on hand to put back. It drives the optional "restore" offer,
  /// so it is about the config, not the connection: presence gating (the
  /// derailleur has to be here for restore to reach it) lives in [buildChain].
  final bool sramCanRestore;

  /// Whether this controller is a Zwift Click V2 still held out of the connect
  /// queue until the rider picks an unlock mode.
  ///
  /// It is discovered, in range and perfectly healthy — BikeControl is
  /// deliberately not connecting it. Every other step is therefore unknowable
  /// and unactionable, which is why this one replaces them rather than joining
  /// them; without it the card reported "never paired" and "bring it back in
  /// range" about a controller sitting switched on beside the rider.
  final bool needsUnlockModeChoice;

  /// Whether this is a Click V2 right puck whose lights would stay lit if a
  /// left puck were switched on nearby. An offer, never a requirement — the
  /// puck stays powered on either way, only its lights differ.
  final bool clickV2NeedsLeftSide;
}

class TrainerInput {
  const TrainerInput({
    required this.deviceId,
    required this.name,
    required this.presence,
    required this.appHoldsBridge,
    this.bridgeName,
    this.metrics,
    this.overlayOffered = false,
    this.overlayEnabled = false,
    this.overlayAnswered = false,
    this.overlayDeclined = false,
  });

  final String deviceId;
  final String name;

  /// Presence here means *bridged* — the bridge is running for this trainer —
  /// not merely that its Bluetooth link is up. That is the distinction
  /// onboarding draws (`onboardingTrainerBridged`), and the one that matters:
  /// a trainer BikeControl is talking to but isn't bridging does nothing for
  /// the rider.
  final DevicePresence presence;

  /// Whether the trainer app has actually picked up the virtual trainer, as
  /// opposed to the bridge merely running. Mirrors
  /// `ProxyDevice.isConnectedListenable`, the same flag onboarding's summary
  /// uses to decide between "Bridged" and "Waiting for {app}…".
  final bool appHoldsBridge;

  /// What the bridge advertises itself as, e.g. "KICKR CORE - BikeControl" —
  /// the entry a rider has to pick in their trainer app, and the one they most
  /// often miss.
  final String? bridgeName;

  /// Live telemetry for the ready-state status line, e.g. "250 W · 90 rpm".
  final String? metrics;

  /// Whether the gear overlay is worth offering on this trainer's card at all.
  ///
  /// Three things have to hold, and the card asks about none of them itself:
  /// the trainer app runs on *this* device (an overlay cannot be drawn over an
  /// app on someone else's iPad), the platform can draw one, and BikeControl is
  /// actually computing gears (a Virtual Shifting session) — without that last
  /// one there is no gear for the overlay to show, and the offer would be an
  /// answer to a question the rider has not got.
  final bool overlayOffered;

  /// Whether the rider already turned the overlay on, which is what ticks the
  /// step off the card.
  final bool overlayEnabled;

  /// Whether the rider has ever answered the overlay step — turned the
  /// overlay on, or said "Not now". The step is required only until then: it
  /// holds the card amber once, not after every ride. An overlay that was on
  /// and has since been switched off (the trainer page's switch, the Live
  /// Activity's "stop ride") is an offer again, never outstanding work.
  final bool overlayAnswered;

  /// Whether the rider's answer was "Not now". Takes the step off the card
  /// until the overlay is turned on (which clears it — see
  /// `Settings.setOverlayEnabled`).
  final bool overlayDeclined;
}

class AppInput {
  const AppInput({
    this.name,
    this.selfHosted = false,
    this.hasEnabledConnection = false,
    this.isConnected = false,
    this.wasConnectedThisSession = false,
    this.connectionSummary,
    this.localControlOffered = false,
    this.localControlEnabled = false,
    this.localNetworkGranted,
  });

  /// The selected trainer app, or null when the rider hasn't picked one.
  final String? name;

  /// BikeControl-as-trainer-app runs the workout itself, so "which connection
  /// method reaches it" is meaningless — both connection steps are satisfied
  /// by definition.
  final bool selfHosted;

  final bool hasEnabledConnection;
  final bool isConnected;

  /// Drives the red "lost connection" state, same rule as devices.
  final bool wasConnectedThisSession;

  /// e.g. "Network" — which method is carrying the commands.
  final String? connectionSummary;

  /// Whether Local control is available on this device but switched off.
  ///
  /// Local is what lets a button send a keystroke or a click to the trainer
  /// app running on this very machine, and it is the gate on a whole class of
  /// actions in the button editor — so a rider riding on this device with it
  /// off is missing options they never learn exist. It needs the app to be on
  /// the same machine, which is why it is offered on the app card and only
  /// when the rider's target is this device.
  final bool localControlOffered;

  /// Whether Local is already on, which is what ticks the optional step off.
  final bool localControlEnabled;

  /// Apple's Local Network permission, or null when it does not apply: no
  /// network method is switched on, the platform has no such permission, or it
  /// has never been measured. Null keeps the step out of the checklist
  /// entirely, so a rider is never shown work that isn't theirs to do.
  final bool? localNetworkGranted;
}

/// Sensors-only mode's stand-in for a smart trainer: there is nothing to
/// bridge, only readings to broadcast to whatever app is listening.
class SensorsInput {
  const SensorsInput({
    required this.sourceNames,
    required this.broadcasting,
    required this.transport,
    this.clientName,
  });

  /// Names of the sensors feeding the broadcast, in display order. The first
  /// one is the card's title.
  final List<String> sourceNames;

  /// Whether the broadcast is actually live right now.
  final bool broadcasting;

  /// How the broadcast reaches the app — proxy, Wi-Fi or Bluetooth.
  final RetrofitMode transport;

  /// The connected app's name, when known.
  final String? clientName;
}

class ChainInputs {
  const ChainInputs({
    this.bluetoothReady = true,
    this.controllers = const [],
    this.trainer,
    this.sensors,
    this.app = const AppInput(),
  });

  /// BLE permission granted *and* the adapter powered on.
  final bool bluetoothReady;

  /// Every controller the app knows about — live and remembered — in display
  /// order.
  final List<ControllerInput> controllers;

  /// The smart trainer, when one is known. Null renders the optional
  /// placeholder card.
  final TrainerInput? trainer;

  /// Non-null in sensors-only mode: replaces the trainer link with a sensors
  /// link. Ignored when [trainer] is also set — a rider with a trainer is no
  /// longer in sensors-only mode, and the trainer link wins.
  final SensorsInput? sensors;

  final AppInput app;
}
