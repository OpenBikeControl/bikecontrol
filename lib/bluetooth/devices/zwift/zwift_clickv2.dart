import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:bike_control/widgets/unlock_confirm.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:prop/emulators/definitions/zwift_click_definition.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

final DirconEmulator ftmsEmulator = DirconEmulator();

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickDefinition? _clickDef;
  ZwiftClickDefinition? get clickDef => _clickDef;

  /// Unlock-flow state owned by the Click device itself, not the shared emulator.
  final ValueNotifier<bool> isUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> alreadyUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> waiting = ValueNotifier(false);

  /// Vendor message captured from ZWIFT_ASYNC notifications during the unlock
  /// handshake. Persisted so reconnects can replay it to Zwift.
  Uint8List? _vendorMessage;

  /// When this device connected. Used by the unlock page to compute timeouts.
  DateTime? connectionDate;

  ZwiftClickV2(super.scanResult)
    : super(
        isBeta: true,
        availableButtons: [
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
  String get latestFirmwareVersion => '1.1.0';

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

  @override
  String toString() {
    return screenshotMode ? 'Controller' : "Zwift Click V2";
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
    await ftmsEmulator.attachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
      recordError(e, s, context: 'ZwiftClickV2.attachClickDef');
    });

    await super.handleServices(services);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    // Capture the vendor challenge message from the Click so it can be
    // replayed to Zwift on reconnect (unlock handshake recovery).
    if (characteristic.toUpperCase() == FtmsMdnsConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID &&
        bytes.length >= 2 &&
        Opcode.valueOf(bytes[0]) == Opcode.VENDOR_MESSAGE &&
        bytes[1] == 0x03) {
      _vendorMessage = Uint8List.fromList(bytes);
    }

    // All click traffic goes to ftmsEmulator — it's the single shared emulator
    // for VS mode and the standalone emulator for the click-alone path.
    final processed = ftmsEmulator.processCharacteristic(characteristic, bytes);
    if (!processed || true) {
      await super.processCharacteristic(characteristic, bytes);
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
    final lastUnlockDate = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    if (!isConnected || screenshotMode) return [];
    if (isPersistedUnlocked && lastUnlockDate != null && isLikelyUnlocked) {
      return [
        Warning(
          important: false,
          children: [
            Row(
              spacing: 12,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.gray,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.lock_open_rounded, color: Colors.white),
                ),
                Flexible(
                  child: Text(
                    'Likely unlocked until ${DateFormat('EEEE, HH:MM').format(lastUnlockDate.add(const Duration(days: 1)))}',
                  ).xSmall,
                ),
                Button.outline(
                  child: Text('Unlock again'),
                  onPressed: () {
                    openDrawer(
                      context: context,
                      position: OverlayPosition.bottom,
                      builder: (_) => UnlockPage(device: this),
                    );
                  },
                ),
              ],
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
            Row(
              spacing: 12,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.lock_open_rounded, color: Colors.white),
                ),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).unlock_unlockedUntilAroundDate(
                      DateFormat('EEEE, HH:MM').format(lastUnlockDate.add(const Duration(days: 1))),
                    ),
                  ).xSmall,
                ),
                Button.outline(
                  child: Text('Unlock again'),
                  onPressed: () {
                    openDrawer(
                      context: context,
                      position: OverlayPosition.bottom,
                      builder: (_) => UnlockPage(device: this),
                    );
                  },
                ),
              ],
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
          Row(
            spacing: 8,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.lock_rounded, color: Colors.white),
              ),
              Flexible(
                child: Text(AppLocalizations.of(context).unlock_deviceIsCurrentlyLocked).xSmall,
              ),
              Builder(
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
            ],
          ),
          if (kDebugMode)
            Button(
              onPressed: () {
                sendCommand(Opcode.RESET, null);
              },
              leading: const Icon(Icons.translate_sharp),
              style: ButtonStyle.primary(size: ButtonSize.small),
              child: Text('Reset'),
            ),
        ],
      ),
    ];
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
    // other Click is still connected.
    final anotherClick = core.connection.devices.any(
      (d) => d is ZwiftClickV2 && !identical(d, this),
    );
    if (ftmsEmulator.composite.children.isEmpty && ftmsEmulator.isStarted.value && !anotherClick) {
      ftmsEmulator.stop();
    }
    await super.disconnect();
  }
}
