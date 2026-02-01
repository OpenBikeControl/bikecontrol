import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:prop/emulators/ftms_emulator.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

final FtmsEmulator emulator = FtmsEmulator();

class ZwiftClickV2 extends ZwiftRide {
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
    emulator.setScanResult(scanResult);
  }

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  String get latestFirmwareVersion => '1.1.0';

  @override
  bool get canVibrate => false;

  @override
  String toString() {
    return "$name V2";
  }

  bool get isUnlocked {
    final lastUnlock = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    if (lastUnlock == null) {
      return false;
    }
    return lastUnlock > DateTime.now().subtract(const Duration(days: 1));
  }

  @override
  Future<void> setupHandshake() async {
    if (isUnlocked) {
      super.setupHandshake();
    }
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    emulator.handleServices(services);
    await super.handleServices(services);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (!emulator.processCharacteristic(characteristic, bytes)) {
      await super.processCharacteristic(characteristic, bytes);
    }
  }

  @override
  Widget showInformation(BuildContext context) {
    final lastUnlockDate = propPrefs.getZwiftClickV2LastUnlock(scanResult.deviceId);
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            super.showInformation(context),

            if (isConnected && !core.settings.getShowOnboarding())
              if (isUnlocked && lastUnlockDate != null)
                Warning(
                  important: false,
                  children: [
                    Row(
                      spacing: 8,
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
                        Tooltip(
                          tooltip: (c) => Text('Unlock again'),
                          child: IconButton.ghost(
                            icon: Icon(Icons.lock_reset_rounded),

                            onPressed: () {
                              openDrawer(
                                context: context,
                                position: OverlayPosition.bottom,
                                builder: (_) => UnlockPage(device: this),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
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
                        Flexible(child: Text(AppLocalizations.of(context).unlock_deviceIsCurrentlyLocked).xSmall),
                        Button(
                          onPressed: () {
                            openDrawer(
                              context: context,
                              position: OverlayPosition.bottom,
                              builder: (_) => UnlockPage(device: this),
                            );
                          },
                          leading: const Icon(Icons.lock_open_rounded),
                          style: ButtonStyle.primary(size: ButtonSize.small),
                          child: Text(AppLocalizations.of(context).unlock_unlockNow),
                        ),
                      ],
                    ),
                    if (kDebugMode && !isUnlocked)
                      Button(
                        onPressed: () {
                          super.setupHandshake();
                        },
                        leading: const Icon(Icons.handshake),
                        style: ButtonStyle.primary(size: ButtonSize.small),
                        child: Text('Handshake'),
                      ),
                  ],
                ),
            /*else
              Warning(
                important: false,
                children: [
                  Text(
                    AppLocalizations.of(context).clickV2EventInfo,
                  ).xSmall,
                  LinkButton(
                    child: Text(context.i18n.troubleshootingGuide),
                    onPressed: () {
                      openDrawer(
                        context: context,
                        position: OverlayPosition.bottom,
                        builder: (_) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                      );
                    },
                  ),
                ],
              ),*/
          ],
        );
      },
    );
  }

  Future<void> test() async {
    await sendCommand(Opcode.RESET, null);
    //await sendCommand(Opcode.GET, Get(dataObjectId: VendorDO.PAGE_DEVICE_PAIRING.value)); // 0008 82E0 03

    /*await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_DEV_INFO.value)); // 0008 00
    await sendCommand(Opcode.LOG_LEVEL_SET, LogLevelSet(logLevel: LogLevel.LOGLEVEL_TRACE)); // 4108 05

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10
    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10
    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CLIENT_SERVER_CONFIGURATION.value)); // 0008 10

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.PAGE_CONTROLLER_INPUT_CONFIG.value)); // 0008 80 08

    await sendCommand(Opcode.GET, Get(dataObjectId: DO.BATTERY_STATE.value)); // 0008 83 06

    // 	Value: FF04 000A 1540 E9D9 C96B 7463 C27F 1B4E 4D9F 1CB1 205D 882E D7CE
    // 	Value: FF04 000A 15B2 6324 0A31 D6C6 B81F C129 D6A4 E99D FFFC B9FC 418D
    await sendCommandBuffer(
      Uint8List.fromList([
        0xFF,
        0x04,
        0x00,
        0x0A,
        0x15,
        0xC2,
        0x63,
        0x24,
        0x0A,
        0x31,
        0xD6,
        0xC6,
        0xB8,
        0x1F,
        0xC1,
        0x29,
        0xD6,
        0xA4,
        0xE9,
        0x9D,
        0xFF,
        0xFC,
        0xB9,
        0xFC,
        0x41,
        0x8D,
      ]),
    );*/
  }
}
