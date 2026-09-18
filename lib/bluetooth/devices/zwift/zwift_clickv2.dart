import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:bike_control/widgets/unlock_confirm.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

// TrainerRoad hard-dials the standard Wahoo DirCon port, ignoring the mDNS SRV
// port. Reasoning in `prop` ([kWahooDirconStandardPort]).
final DirconEmulator ftmsEmulator = DirconEmulator()..preferStandardPort = bridgeServesStandardDirconPort;

/// Whether the trainer bridges serve on the standard Wahoo DirCon port.
/// TrainerRoad has no entry of its own, so its riders pick "Other"; every
/// named app keeps the auto-assigned port it had before 7.0.
bool bridgeServesStandardDirconPort() => core.settings.getTrainerApp() is CustomApp;

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickDefinition? _clickDef;
  ZwiftClickDefinition? get clickDef => _clickDef;

  /// Whether this Click's definition rides on the shared bridge composite.
  ///
  /// Zwift wants the Click co-located with the trainer on one endpoint. Rouvy
  /// is the opposite: it refuses to pair a trainer bridge that carries a
  /// controller service alongside the trainer (the pairing dialog spins
  /// forever), and it takes its controller input from the standalone
  /// controller endpoint, where this Click is served anyway.
  bool get attachesClickDefToBridge => core.settings.getTrainerApp() is! Rouvy;

  /// React to a trainer-app change while this Click is connected: put the
  /// Click's definition on or take it off the shared composite to match
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

  /// Test seam — [_clickDef] is normally built during the BLE connect flow.
  @visibleForTesting
  void debugSetClickDef(ZwiftClickDefinition def) => _clickDef = def;

  /// Unlock-flow state owned by the Click device itself, not the shared emulator.
  final ValueNotifier<bool> isUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> alreadyUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> waiting = ValueNotifier(false);

  /// Vendor message captured from ZWIFT_ASYNC notifications during the unlock
  /// handshake. Persisted so reconnects can replay it to Zwift.
  Uint8List? _vendorMessage;

  /// When this device connected. Used by the unlock page to compute timeouts.
  DateTime? connectionDate;

  ZwiftClickV2(super.scanResult, {List<ControllerButton>? availableButtons})
    : super(
        isBeta: true,
        availableButtons:
            availableButtons ??
            [
              ZwiftButtons.navigationLeft,
              ZwiftButtons.navigationRight,
              ZwiftButtons.navigationUp,
              ZwiftButtons.navigationDown,
              ZwiftButtons.a,
              ZwiftButtons.b,
              ZwiftButtons.y,
              ZwiftButtons.z,
              ZwiftButtons.shiftUpLeft,
              ZwiftButtons.shiftUpRight,
            ],
      ) {
    connectionDate = DateTime.now();
  }

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  String get latestFirmwareVersion => '1.2.0';

  @override
  bool get canVibrate => false;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 494.86 / 252.86,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/zwift_click_v2.svg',
    positions: {
      // Left puck — navigation diamond + minus (shift-up-left) under "down".
      ZwiftButtons.navigationUp: const Offset(0.227, 0.25),
      ZwiftButtons.navigationLeft: const Offset(0.119, 0.44),
      ZwiftButtons.navigationRight: const Offset(0.335, 0.44),
      ZwiftButtons.navigationDown: const Offset(0.227, 0.62),
      ZwiftButtons.shiftUpLeft: const Offset(0.227, 0.87),
      // Right puck — face-button diamond. Per the physical device: Y top,
      // Z left, A right, B bottom. Plus (shift-up-right) sits under B.
      ZwiftButtons.y: const Offset(0.773, 0.25),
      ZwiftButtons.z: const Offset(0.665, 0.44),
      ZwiftButtons.a: const Offset(0.870, 0.44),
      ZwiftButtons.b: const Offset(0.773, 0.62),
      ZwiftButtons.shiftUpRight: const Offset(0.773, 0.87),
    },
  );

  /// The name written to the ignored-devices list alongside the id. Matched
  /// back by [ClickV2Onboarding.restoreLeftSides], which has to recognise both
  /// this and [ZwiftClickV2LeftSide.label]: in the legacy representation the
  /// left puck IS this unified controller.
  static const label = 'Zwift Click V2';

  @override
  String toString() {
    return screenshotMode ? 'Controller' : label;
  }

  /// Whether the device was successfully unlocked within the last 24 hours,
  /// according to persistent storage. Distinct from [isUnlocked] which holds
  /// the live session-unlock notifier.
  bool get isPersistedUnlocked {
    final lastUnlock = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    if (lastUnlock == null) {
      return false;
    }
    return lastUnlock > DateTime.now().subtract(const Duration(days: 1));
  }

  bool get isLikelyUnlocked {
    return propPrefs.notSureIfUnlocked(scanResult.deviceId);
  }

  /// When the current unlock runs out, or null if this Click was never
  /// unlocked. Exposed so callers outside this file (the home chain's unlock
  /// step) can show the deadline without reaching into `propPrefs` themselves.
  DateTime? get unlockedUntil {
    final lastUnlock = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    return lastUnlock?.add(const Duration(days: 1));
  }

  /// Held out of the connect queue until the rider has chosen an unlock mode.
  /// Zwift Click V2 behaviour depends entirely on that choice, so connecting
  /// first would hand them a controller that half-works for reasons they have
  /// not been told about yet.
  @override
  bool get shouldAutoConnect => !ClickV2Onboarding.isPending;

  @override
  Future<void> connect() async {
    // Mirrors ProxyDevice: stay listed and keep the queue's listener wiring,
    // but open no transport and run no handshake while onboarding is pending.
    if (!shouldAutoConnect) return;
    await super.connect();
  }

  @override
  Future<void> setupHandshake() async {
    final hasScript = await DeviceScriptService.instance.hasCustomScript(runtimeType.toString());
    if (isPersistedUnlocked || hasScript) {
      super.setupHandshake();
      await sendCommandBuffer(Uint8List.fromList([0xFF, 0x04, 0x00]));
    }
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    // Clear stale unlock-state notifiers so a reconnect doesn't show
    // leftover "already unlocked" / "waiting" from a previous attempt.
    isUnlocked.value = false;
    alreadyUnlocked.value = false;
    waiting.value = false;

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
    );

    // Attach the click def to the shared emulator. If a trainer is already
    // running in VS mode its FBD will already be in the composite; if not the
    // emulator starts standalone so Zwift sees the Click right away.
    //
    // Not for Rouvy: it refuses to pair a trainer bridge that carries a
    // controller service alongside the trainer — the pairing dialog spins
    // forever — and it takes its controller input from the standalone
    // controller endpoint instead, where this Click is already served.
    if (attachesClickDefToBridge) {
      await ftmsEmulator.attachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'ZwiftClickV2.attachClickDef');
      });
    }

    await super.handleServices(services);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    // Capture the vendor challenge message from the Click so it can be
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

    if (isLikelyUnlocked && initializationTime != null) {
      if (initializationTime!.add(Duration(minutes: 1)).isBefore(DateTime.now())) {
        propPrefs.setNotSureIfUnlocked(scanResult.deviceId, false);
      }
    }
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    // The unlock modes are a Zwift-specific caveat and name the controller
    // outright — neither belongs on an anonymized store board.
    if (screenshotMode) return [];
    return [
      // The unified controller is where unlock-with-Zwift lands the rider, so
      // the way back into the explainer has to be here too — otherwise
      // arriving on it is a one-way trip with no route to right-side-only.
      // Empty children: unlike the left puck, this card shows its unlock
      // warnings in every mode (below), not only in unlock-with-Zwift.
      const UnlockToggle(children: []),
      ...unlockWarnings(context),
    ];
  }

  /// The unlock-status warning(s) for this Click. Split out from
  /// [showAdditionalInformation] so [ZwiftClickV2LeftSide] can wrap exactly
  /// these in its unlock-mode toggle.
  List<Widget> unlockWarnings(BuildContext context) {
    final lastUnlockDate = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    if (!isConnected || screenshotMode) return [];
    if (isPersistedUnlocked && lastUnlockDate != null && isLikelyUnlocked) {
      return [
        Warning(
          important: false,
          children: [
            _unlockStatusLine(
              iconColor: Colors.gray,
              icon: Icons.lock_open_rounded,
              text: Text(
                'Likely unlocked until ${DateFormat('EEEE, HH:mm').format(lastUnlockDate.add(const Duration(days: 1)))}',
              ).xSmall,
              action: _unlockAgainButton(context),
            ),
            if (initializationTime != null) UnlockConfirm(device: this),
          ],
        ),
      ];
    } else if (isPersistedUnlocked && lastUnlockDate != null) {
      return [
        Warning(
          important: false,
          children: [
            _unlockStatusLine(
              iconColor: Colors.green,
              icon: Icons.lock_open_rounded,
              text: Text(
                AppLocalizations.of(context).unlock_unlockedUntilAroundDate(
                  DateFormat('EEEE, HH:mm').format(lastUnlockDate.add(const Duration(days: 1))),
                ),
              ).xSmall,
              action: _unlockAgainButton(context),
            ),
            if (kDebugMode) ...[
              Button(
                onPressed: () {
                  sendCommand(Opcode.RESET, null);
                },
                leading: const Icon(Icons.translate_sharp),
                style: ButtonStyle.primary(size: ButtonSize.small),
                child: Text('Reset'),
              ),
            ],
          ],
        ),
      ];
    }
    return [
      Warning(
        important: false,
        children: [
          _unlockStatusLine(
            iconColor: Colors.red,
            icon: Icons.lock_rounded,
            text: Text(AppLocalizations.of(context).unlock_deviceIsCurrentlyLocked).xSmall,
            action: Builder(
              builder: (context) {
                return Button(
                  onPressed: () {
                    showDropdown(
                      context: context,
                      builder: (c) => DropdownMenu(
                        children: [
                          MenuButton(
                            leading: const Icon(Icons.check),
                            onPressed: (c) {
                              propPrefs.setZwiftClickV2LastUnlock(scanResult.deviceId, DateTime.now());
                              propPrefs.setNotSureIfUnlocked(scanResult.deviceId, true);
                              super.setupHandshake();
                            },
                            child: Text(context.i18n.unlock_markAsUnlocked),
                          ),
                          MenuDivider(),
                          MenuButton(
                            onPressed: (c) {
                              openDrawer(
                                context: context,
                                position: OverlayPosition.bottom,
                                builder: (_) => UnlockPage(device: this),
                              );
                            },
                            leading: const Icon(Icons.lock_open_rounded),
                            child: Text(AppLocalizations.of(context).unlock_unlockNow),
                          ),
                        ],
                      ),
                    );
                  },
                  leading: const Icon(Icons.lock_open_rounded),
                  style: ButtonStyle.outline(size: ButtonSize.small),
                  child: Text(AppLocalizations.of(context).unlock_unlockNow),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  Button _unlockAgainButton(BuildContext context) {
    return Button.outline(
      child: Text('Unlock again'),
      onPressed: () {
        openDrawer(
          context: context,
          position: OverlayPosition.bottom,
          builder: (_) => UnlockPage(device: this),
        );
      },
    );
  }

  /// One unlock-status line: a status icon badge, a short message and a trailing
  /// action. On a narrow card — e.g. the left and right sides shown side by side
  /// — the action drops below the text instead of being squeezed into an
  /// unreadable sliver, which previously pushed the "Unlock again" button up out
  /// of line with the wrapped text.
  Widget _unlockStatusLine({
    required Color iconColor,
    required IconData icon,
    required Widget text,
    required Widget action,
  }) {
    final iconBadge = Container(
      decoration: BoxDecoration(
        color: iconColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(icon, color: Colors.white),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  iconBadge,
                  Flexible(child: text),
                ],
              ),
              action,
            ],
          );
        }
        return Row(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconBadge,
            Flexible(child: text),
            action,
          ],
        );
      },
    );
  }

  @override
  Future<void> disconnect() async {
    if (_clickDef != null) {
      await ftmsEmulator.detachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'ZwiftClickV2.detach');
      });
      _clickDef = null;
    }
    // Stop the shared emulator if nothing else lives in its composite and no
    // other Click is still connected. Checks hasNothingToServe rather than
    // composite.children.isEmpty directly for the same reason
    // ProxyDevice._stopFtmsEmulatorIfUnused does: a SensorDefinition riding
    // along must not, on its own, be the reason the bridge looks in use.
    final anotherClick = core.connection.devices.any(
      (d) => d is ZwiftClickV2 && !identical(d, this),
    );
    if (ftmsEmulator.hasNothingToServe && ftmsEmulator.isStarted.value && !anotherClick) {
      ftmsEmulator.stop();
    }
    await super.disconnect();
  }
}
