import 'dart:io';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pbenum.dart' show LogLevel;
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';

import '../utils/requirements/multi.dart';

class RemotePairingWidget extends StatefulWidget {
  const RemotePairingWidget({super.key});

  @override
  State<RemotePairingWidget> createState() => _PairWidgetState();
}

class _PairWidgetState extends State<RemotePairingWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.remotePairing.isStarted,
      builder: (context, isStarted, child) {
        return ValueListenableBuilder(
          valueListenable: core.remotePairing.isConnected,
          builder: (context, isConnected, child) {
            return ConnectionMethod(
              isEnabled: core.logic.isRemoteControlEnabled,
              isStarted: isStarted,
              showTroubleshooting: true,
              type: ConnectionMethodType.bluetooth,
              title: context.i18n.enablePairingProcess,
              description: context.i18n.pairingDescription,
              isConnected: isConnected,
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) async {
                core.settings.setRemoteControlEnabled(value);
                if (!value) {
                  core.remotePairing.stopAdvertising();
                } else {
                  core.remotePairing.startAdvertising().catchError((e) {
                    core.settings.setRemoteControlEnabled(false);
                    core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()));
                  });
                }
                setState(() {});
              },
              additionalChild: isStarted
                  ? Text(
                      switch (core.settings.getLastTarget()) {
                        Target.otherDevice when Platform.isIOS => context.i18n.pairingInstructionsIOS,
                        _ => context.i18n.pairingInstructions(core.settings.getLastTarget()?.getTitle(context) ?? ''),
                      },
                    ).xSmall
                  : null,
            );
          },
        );
      },
    );
  }
}
