import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/ui/warning.dart';

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
      );

  bool _noLongerSendsEvents = false;

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  String get latestFirmwareVersion => '1.1.0';

  @override
  bool get canVibrate => false;

  @override
  Future<void> setupHandshake() async {
    super.setupHandshake();
    await sendCommandBuffer(Uint8List.fromList([0xFF, 0x04, 0x00]));
  }

  @override
  Future<void> processData(Uint8List bytes) {
    if (bytes.startsWith(ZwiftConstants.RESPONSE_STOPPED_CLICK_V2_VARIANT_1) ||
        bytes.startsWith(ZwiftConstants.RESPONSE_STOPPED_CLICK_V2_VARIANT_2)) {
      _noLongerSendsEvents = true;
      actionStreamInternal.add(
        AlertNotification(
          LogLevel.LOGLEVEL_WARNING,
          'Your Zwift Click V2 no longer sends events. Connect it in the Zwift app once each session.',
        ),
      );
    }
    return super.processData(bytes);
  }

  @override
  Widget showInformation(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        super.showInformation(context),

        if (isConnected && _noLongerSendsEvents && core.settings.getShowZwiftClickV2ReconnectWarning())
          Warning(
            children: [
              Text(
                '''To make your Zwift Click V2 work best you should connect it in the Zwift app once each day.\nIf you don't do that BikeControl will need to reconnect every minute.

1. Open Zwift app
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Zwift Click V2
4. Close the Zwift app again and connect again in BikeControl''',
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      sendCommand(Opcode.RESET, null);
                    },
                    child: Text('Reset now'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                        ),
                      );
                    },
                    child: Text('Troubleshooting'),
                  ),
                  if (kDebugMode && false)
                    TextButton(
                      onPressed: () {
                        test();
                      },
                      child: Text('Test'),
                    ),
                  Expanded(child: SizedBox()),
                  TextButton(
                    onPressed: () {
                      core.settings.setShowZwiftClickV2ReconnectWarning(false);
                    },
                    child: Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
      ],
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
