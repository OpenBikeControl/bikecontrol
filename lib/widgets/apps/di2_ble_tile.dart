import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';

class Di2BleTile extends StatefulWidget {
  final bool small;
  const Di2BleTile({super.key, required this.small});

  @override
  State<Di2BleTile> createState() => _Di2BleTileState();
}

class _Di2BleTileState extends State<Di2BleTile> {
  @override
  Widget build(BuildContext context) {
    final emulator = core.di2Emulator;
    return ValueListenableBuilder(
      valueListenable: emulator.isConnected,
      builder: (context, isConnected, _) {
        return ValueListenableBuilder(
          valueListenable: emulator.isStarted,
          builder: (context, isStarted, _) {
            return ConnectionMethod(
              small: widget.small,
              trainerConnection: emulator,
              isRecommended: true,
              supportLevel: core.settings.getTrainerApp()?.supportLevel(AppConnectionMethod.di2Ble),
              isEnabled: core.settings.getDi2BleEnabled(),
              onChange: (value) async {
                if (value) {
                  await core.stopAllBleConnections();
                }
                await core.settings.setDi2BleEnabled(value);
                if (!value) {
                  await emulator.stopAdvertising();
                } else {
                  emulator.startAdvertising().catchError((e, s) {
                    recordError(e, s, context: 'Di2 Emulator');
                    core.settings.setDi2BleEnabled(false);
                    emulator.stopAdvertising();
                    core.connection.signalNotification(
                      AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()),
                    );
                  });
                }
                if (mounted) setState(() {});
              },
              title: context.i18n.connectUsingBluetooth,
              description: !isStarted
                  ? 'Pair your Wahoo ELEMNT to BikeControl as a Shimano Di2 D-Fly shifter.'
                  : isConnected
                  ? context.i18n.connected
                  : 'Waiting for the Wahoo ELEMNT to connect…',
              requirements: core.permissions.getRemoteControlRequirements(),
            );
          },
        );
      },
    );
  }
}
