import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/emulator_registry.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/unlock.dart';
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
  DirconEmulator _currentEmulator = ftmsEmulator;
  ZwiftClickDefinition? _clickDef;
  List<BleService>? _cachedServices;
  late final VoidCallback _onSharedTrainerChangedListener = _onSharedTrainerChanged;

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
    _currentEmulator = EmulatorRegistry.instance.resolveFor(standalone: ftmsEmulator);
    if (identical(_currentEmulator, ftmsEmulator)) {
      _currentEmulator.setScanResult(scanResult);
    }
    EmulatorRegistry.instance.sharedTrainerEmulator.addListener(_onSharedTrainerChangedListener);
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

  bool get isUnlocked {
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
    if (isUnlocked || hasScript) {
      super.setupHandshake();
      await sendCommandBuffer(Uint8List.fromList([0xFF, 0x04, 0x00]));
    }
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    _cachedServices = services;
    // Click's BLE info lives inside the ZwiftClickDefinition (services /
    // device args). The emulator-level scanResult / services fields belong
    // to the EMULATOR's primary device — the trainer for trainer's
    // emulator, the Click for the standalone. Don't overwrite the
    // trainer's identity here.
    if (identical(_currentEmulator, ftmsEmulator)) {
      _currentEmulator.handleServices(services);
    }
    _clickDef = ZwiftClickDefinition(
      services: services,
      device: scanResult,
      data: ftmsEmulator.data,
      vendorMessage: null,
      isUnlocked: ftmsEmulator.isUnlocked,
      alreadyUnlocked: ftmsEmulator.alreadyUnlocked,
      waiting: ftmsEmulator.waiting,
      isStarted: ftmsEmulator.isStarted,
      connectionDate: ftmsEmulator.connectionDate ?? DateTime.now(),
    );
    await _currentEmulator.attachDefinition(_clickDef!).catchError((Object e, StackTrace s) {
      recordError(e, s, context: 'ZwiftClickV2.handleServices');
    });
    if (identical(_currentEmulator, ftmsEmulator) && !_currentEmulator.isStarted.value) {
      await _currentEmulator.startServer();
    }
    await super.handleServices(services);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    final processed = _currentEmulator.processCharacteristic(characteristic, bytes);
    if (!processed) {
      await super.processCharacteristic(characteristic, bytes);
    } else {
      if (bytes.startsWith(startCommand)) {
        initializationTime = DateTime.now();
      }
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
    if (isUnlocked && lastUnlockDate != null && isLikelyUnlocked) {
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
    } else if (isUnlocked && lastUnlockDate != null) {
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

  Future<void> _onSharedTrainerChanged() async {
    final target = EmulatorRegistry.instance.resolveFor(standalone: ftmsEmulator);
    if (identical(target, _currentEmulator)) return;
    final clickDef = _clickDef;
    final services = _cachedServices;
    if (clickDef == null || services == null) {
      // We haven't attached yet — just remember the new target.
      _currentEmulator = target;
      return;
    }

    await _currentEmulator.detachDefinition(clickDef).catchError((Object e, StackTrace s) {
      recordError(e, s, context: 'ZwiftClickV2.rebindDetach');
    });
    // If we're leaving the standalone for a trainer's emulator, stop the
    // standalone so we don't leak a second peripheral.
    if (identical(_currentEmulator, ftmsEmulator) && !identical(target, ftmsEmulator)) {
      _currentEmulator.stop();
    }
    _currentEmulator = target;
    if (identical(_currentEmulator, ftmsEmulator)) {
      _currentEmulator.setScanResult(scanResult);
      _currentEmulator.handleServices(services);
    }
    await _currentEmulator.attachDefinition(clickDef).catchError((Object e, StackTrace s) {
      recordError(e, s, context: 'ZwiftClickV2.rebindAttach');
    });
    if (identical(_currentEmulator, ftmsEmulator) && !_currentEmulator.isStarted.value) {
      await _currentEmulator.startServer();
    }
  }

  @override
  Future<void> disconnect() async {
    EmulatorRegistry.instance.sharedTrainerEmulator.removeListener(_onSharedTrainerChangedListener);
    final clickDef = _clickDef;
    if (clickDef != null) {
      await _currentEmulator.detachDefinition(clickDef).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'ZwiftClickV2.disconnect');
      });
      _clickDef = null;
    }
    await super.disconnect();
  }
}
