import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/unlock_confirm.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:prop/prop.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

// TrainerRoad hard-dials the standard Wahoo DirCon port, ignoring the mDNS SRV
// port. Reasoning in `prop` ([kWahooDirconStandardPort]).
final DirconEmulator ftmsEmulator = DirconEmulator()..preferStandardPort = bridgeServesStandardDirconPort;

/// Whether the trainer bridges serve on the standard Wahoo DirCon port.
/// TrainerRoad has no entry of its own, so its riders pick "Other"; every
/// named app keeps the auto-assigned port it had before 7.0.
bool bridgeServesStandardDirconPort() => core.settings.getTrainerApp() is CustomApp;

/// The blog post that explains why these controllers need unlocking.
const zwiftUnlockBlogUrl = 'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps/';

/// The unlock-with-Zwift capability shared by every Zwift controller that Zwift
/// locks to its own app: the Zwift Click V2 and the Zwift Ride V2.
///
/// Owns the unlock state (live notifiers plus the persisted 24-hour window),
/// the bridge definition Zwift unlocks the controller through, the gated
/// handshake and the unlock status lines. Everything is dormant unless
/// [usesZwiftUnlock] is true, so a plain Zwift Ride (or a Click V2 right puck)
/// that merely inherits it behaves exactly as before.
mixin ZwiftUnlock on ZwiftDevice {
  /// Whether the unlock machinery runs for this device right now: the bridge
  /// definition, the gated handshake and the routing of notifications through
  /// the shared emulator.
  bool get usesZwiftUnlock => false;

  /// Whether the rider has to unlock this controller with Zwift — the
  /// capability the UI keys on (home chain step, status lines, unlock page).
  /// Usually the same as [usesZwiftUnlock]; the Click V2 left puck narrows it
  /// to the unlock-with-Zwift mode.
  bool get requiresZwiftUnlock => usesZwiftUnlock;

  /// Whether this controller offers the Click V2 unlock modes (right side
  /// only, restart every minute). Only the Click V2 does; a Zwift Ride V2
  /// always unlocks with Zwift.
  bool get offersUnlockModes => false;

  /// Whether this is a Zwift Ride V2 — see [ZwiftRide.isRideV2].
  bool get isRideV2 => false;

  /// Namespace of the persisted unlock timestamp, so each controller family
  /// keeps its own 24-hour window.
  String get unlockKeyPrefix => 'clickV2';

  /// Where "why is this needed?" links to for this controller.
  String get unlockHelpUrl => zwiftUnlockBlogUrl;

  /// When the controller last sent the RideOn response — see [ZwiftRide].
  DateTime? get initializationTime;
  set initializationTime(DateTime? value);

  Future<void> sendCommandBuffer(Uint8List buffer);

  Future<void> sendCommand(Opcode opCode, $pb.GeneratedMessage? message);

  /// Unlock-flow state owned by the device itself, not the shared emulator.
  final ValueNotifier<bool> isUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> alreadyUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> waiting = ValueNotifier(false);

  /// When this device was created. Used by the unlock page to compute timeouts.
  DateTime? connectionDate = DateTime.now();

  /// Set when the controller connected with its Zwift service hidden, i.e.
  /// Zwift has it locked right now. Reset on every connect.
  bool unlockServiceHidden = false;

  ZwiftClickDefinition? _clickDef;
  ZwiftClickDefinition? get clickDef => _clickDef;

  /// Vendor message captured from ZWIFT_ASYNC notifications during the unlock
  /// handshake. Kept so reconnects can replay it to Zwift.
  Uint8List? _vendorMessage;

  /// Test seam — [_clickDef] is normally built during the BLE connect flow.
  @visibleForTesting
  void debugSetClickDef(ZwiftClickDefinition def) => _clickDef = def;

  /// Whether this controller's definition rides on the shared bridge composite.
  ///
  /// Zwift wants the controller co-located with the trainer on one endpoint.
  /// Rouvy is the opposite: it refuses to pair a trainer bridge that carries a
  /// controller service alongside the trainer (the pairing dialog spins
  /// forever), and it takes its controller input from the standalone
  /// controller endpoint, where this controller is served anyway.
  bool get attachesClickDefToBridge => core.settings.getTrainerApp() is! Rouvy;

  /// React to a trainer-app change while this controller is connected: put its
  /// definition on or take it off the shared composite to match
  /// [attachesClickDefToBridge]. Composite-only, like
  /// [ProxyDevice.onTrainerAppChanged] — the caller re-advertises the shared
  /// emulator once after reconciling every device.
  void onTrainerAppChanged() {
    final def = _clickDef;
    if (def == null) return;
    final attached = ftmsEmulator.composite.children.contains(def);
    if (attachesClickDefToBridge && !attached) {
      ftmsEmulator.composite.attach(def);
    } else if (!attachesClickDefToBridge && attached) {
      ftmsEmulator.composite.detach(def);
    }
  }

  /// Whether the controller was successfully unlocked within the last 24
  /// hours, according to persistent storage. Distinct from [isUnlocked] which
  /// holds the live session-unlock notifier.
  bool get isPersistedUnlocked {
    if (unlockServiceHidden) return false;
    final lastUnlock = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId, keyPrefix: unlockKeyPrefix);
    if (lastUnlock == null) {
      return false;
    }
    return lastUnlock > DateTime.now().subtract(const Duration(days: 1));
  }

  bool get isLikelyUnlocked {
    return propPrefs.notSureIfUnlocked(scanResult.deviceId, keyPrefix: unlockKeyPrefix);
  }

  /// When the current unlock runs out, or null if this controller was never
  /// unlocked. Exposed so callers outside this file (the home chain's unlock
  /// step) can show the deadline without reaching into `propPrefs` themselves.
  DateTime? get unlockedUntil {
    final lastUnlock = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId, keyPrefix: unlockKeyPrefix);
    return lastUnlock?.add(const Duration(days: 1));
  }

  /// The rider says the controller is unlocked although BikeControl did not
  /// see it happen. Recorded as a best guess ([isLikelyUnlocked]).
  void markUnlockedManually() {
    propPrefs.setZwiftClickV2LastUnlock(scanResult.deviceId, DateTime.now(), keyPrefix: unlockKeyPrefix);
    propPrefs.setNotSureIfUnlocked(scanResult.deviceId, true, keyPrefix: unlockKeyPrefix);
  }

  /// Called instead of failing when a controller using the Zwift unlock
  /// connects with its Zwift service hidden. Return true when handled — the
  /// connect then completes and the controller shows as locked.
  bool handleHiddenUnlockService() => false;

  /// Sends RideOn without the unlock gate, e.g. after "mark as unlocked".
  Future<void> sendRideOn() => super.setupHandshake();

  @override
  Future<void> setupHandshake() async {
    if (!usesZwiftUnlock) return super.setupHandshake();
    final hasScript = await DeviceScriptService.instance.hasCustomScript(runtimeType.toString());
    if (isPersistedUnlocked || hasScript) {
      super.setupHandshake();
      await sendCommandBuffer(Uint8List.fromList([0xFF, 0x04, 0x00]));
    }
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    if (!usesZwiftUnlock) return super.handleServices(services);

    // Clear stale unlock-state notifiers so a reconnect doesn't show
    // leftover "already unlocked" / "waiting" from a previous attempt.
    isUnlocked.value = false;
    alreadyUnlocked.value = false;
    waiting.value = false;
    unlockServiceHidden = false;

    final hasCustomService = services.any(
      (service) =>
          service.uuid == ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase() ||
          service.uuid == ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
    );
    if (!hasCustomService && handleHiddenUnlockService()) {
      unlockServiceHidden = true;
      return;
    }

    _clickDef = ZwiftClickDefinition(
      services: services,
      device: scanResult,
      data: ftmsEmulator.data,
      vendorMessage: _vendorMessage,
      isUnlocked: isUnlocked,
      alreadyUnlocked: alreadyUnlocked,
      waiting: waiting,
      isStarted: ftmsEmulator.isStarted,
      connectionDate: connectionDate ?? DateTime.now(),
      unlockKeyPrefix: unlockKeyPrefix,
    );

    // Attach the definition to the shared emulator. If a trainer is already
    // running in VS mode its FBD will already be in the composite; if not the
    // emulator starts standalone so Zwift sees the controller right away.
    //
    // Not for Rouvy: it refuses to pair a trainer bridge that carries a
    // controller service alongside the trainer — the pairing dialog spins
    // forever — and it takes its controller input from the standalone
    // controller endpoint instead, where this controller is already served.
    if (attachesClickDefToBridge) {
      await ftmsEmulator.attachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
        recordError(e, s, context: '$runtimeType.attachClickDef');
      });
    }

    await super.handleServices(services);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (!usesZwiftUnlock) return super.processCharacteristic(characteristic, bytes);

    // Capture the vendor challenge message from the controller so it can be
    // replayed to Zwift on reconnect (unlock handshake recovery).
    final opCode = bytes.isNotEmpty ? Opcode.valueOf(bytes[0]) : null;

    if (characteristic.toUpperCase() == FtmsMdnsConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID &&
        bytes.length >= 2 &&
        opCode == Opcode.VENDOR_MESSAGE &&
        bytes[1] == 0x03) {
      _vendorMessage = Uint8List.fromList(bytes);
    }

    if (opCode == Opcode.CONTROLLER_NOTIFICATION) {
      ftmsEmulator.processCharacteristic(characteristic, bytes);
      super.processCharacteristic(characteristic, bytes);
    } else {
      final processed = ftmsEmulator.processCharacteristic(characteristic, bytes);
      if (!processed) {
        await super.processCharacteristic(characteristic, bytes);
      }
    }
    if (bytes.startsWith(startCommand)) {
      initializationTime = DateTime.now();
    }
  }

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    super.handleButtonsClicked(buttonsClicked, longPress: longPress);
    if (!usesZwiftUnlock) return;

    if (isLikelyUnlocked && initializationTime != null) {
      if (initializationTime!.add(const Duration(minutes: 1)).isBefore(DateTime.now())) {
        propPrefs.setNotSureIfUnlocked(scanResult.deviceId, false, keyPrefix: unlockKeyPrefix);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    if (usesZwiftUnlock || _clickDef != null) {
      if (_clickDef != null) {
        await ftmsEmulator.detachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
          recordError(e, s, context: '$runtimeType.detach');
        });
        _clickDef = null;
      }
      // Stop the shared emulator if nothing else lives in its composite and no
      // other unlockable controller is still connected. Checks
      // hasNothingToServe rather than composite.children.isEmpty directly for
      // the same reason ProxyDevice._stopFtmsEmulatorIfUnused does: a
      // SensorDefinition riding along must not, on its own, be the reason the
      // bridge looks in use.
      final anotherUnlockable = core.connection.devices.any(
        (d) => d is ZwiftUnlock && d.usesZwiftUnlock && !identical(d, this),
      );
      if (ftmsEmulator.hasNothingToServe && ftmsEmulator.isStarted.value && !anotherUnlockable) {
        ftmsEmulator.stop();
      }
    }
    await super.disconnect();
  }

  /// Opens the unlock flow for this controller.
  void openUnlockPage(BuildContext context) {
    openDrawer(
      context: context,
      position: OverlayPosition.bottom,
      builder: (_) => UnlockPage(device: this),
    );
  }

  /// The unlock status for this controller: a hairline off the unlock-mode
  /// text above it, the state as a status dot plus words, and its actions as
  /// pills. It sits inside the controller card, so it adds no box of its own.
  List<Widget> unlockWarnings(BuildContext context) {
    final lastUnlockDate = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId, keyPrefix: unlockKeyPrefix);
    if (!isConnected || screenshotMode) return [];
    if (isPersistedUnlocked && lastUnlockDate != null && isLikelyUnlocked) {
      return [
        UnlockStatusPanel(
          label:
              'Likely unlocked until ${DateFormat('EEEE, HH:mm').format(lastUnlockDate.add(const Duration(days: 1)))}',
          tone: BkStatusTone.neutral,
          actions: [_unlockAgainButton(context)],
          footer: [if (initializationTime != null) UnlockConfirm(device: this)],
        ),
      ];
    } else if (isPersistedUnlocked && lastUnlockDate != null) {
      return [
        UnlockStatusPanel(
          label: AppLocalizations.of(context).unlock_unlockedUntilAroundDate(
            DateFormat('EEEE, HH:mm').format(lastUnlockDate.add(const Duration(days: 1))),
          ),
          tone: BkStatusTone.success,
          actions: [
            _unlockAgainButton(context),
            if (kDebugMode)
              BkPillButton.secondary(
                expand: false,
                onPressed: () {
                  sendCommand(Opcode.RESET, null);
                },
                leading: const Icon(LucideIcons.rotateCcw, size: 16),
                child: const Text('Reset'),
              ),
          ],
        ),
      ];
    }
    return [
      UnlockStatusPanel(
        label: AppLocalizations.of(context).unlock_deviceIsCurrentlyLocked,
        tone: BkStatusTone.danger,
        actions: [
          Builder(
            builder: (context) {
              return BkPillButton(
                expand: false,
                onPressed: () {
                  showDropdown(
                    context: context,
                    builder: (c) => DropdownMenu(
                      children: [
                        MenuButton(
                          leading: const Icon(LucideIcons.check),
                          onPressed: (c) {
                            markUnlockedManually();
                            sendRideOn();
                          },
                          child: Text(context.i18n.unlock_markAsUnlocked),
                        ),
                        MenuDivider(),
                        MenuButton(
                          onPressed: (c) => openUnlockPage(context),
                          leading: const Icon(LucideIcons.lockOpen),
                          child: Text(AppLocalizations.of(context).unlock_unlockNow),
                        ),
                      ],
                    ),
                  );
                },
                leading: const Icon(LucideIcons.lockOpen, size: 16),
                child: Text(AppLocalizations.of(context).unlock_unlockNow),
              );
            },
          ),
        ],
      ),
    ];
  }

  Widget _unlockAgainButton(BuildContext context) {
    return BkPillButton.secondary(
      expand: false,
      onPressed: () => openUnlockPage(context),
      child: Text(AppLocalizations.of(context).unlockAgain),
    );
  }
}

/// The unlock state inside a controller card: a hairline that sets it off the
/// unlock-mode text above, the state as a [BkStatusDot], its actions as pills
/// that wrap onto a second line on a narrow card, then any footer (the
/// one-minute confirm countdown). No border and no fill of its own: the card
/// it sits in is already the surface.
class UnlockStatusPanel extends StatelessWidget {
  const UnlockStatusPanel({
    super.key,
    required this.label,
    required this.tone,
    required this.actions,
    this.footer = const [],
  });

  final String label;
  final BkStatusTone tone;
  final List<Widget> actions;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const BkGroupedDivider(indent: 0),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BkStatusDot(label: label, tone: tone),
          ),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ...footer,
        ],
      ),
    );
  }
}
