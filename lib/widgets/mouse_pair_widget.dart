import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/requirements/multi.dart';

class RemoteMousePairingWidget extends StatefulWidget {
  final bool small;
  const RemoteMousePairingWidget({super.key, required this.small});

  @override
  State<RemoteMousePairingWidget> createState() => _PairWidgetState();
}

class _PairWidgetState extends State<RemoteMousePairingWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.remotePairing.isStarted,
      builder: (context, isStarted, child) {
        return ValueListenableBuilder(
          valueListenable: core.remotePairing.isConnected,
          builder: (context, isConnected, child) {
            return ConnectionMethod(
              trainerConnection: core.remotePairing,
              isEnabled: core.logic.isRemoteControlEnabled,
              small: widget.small,
              showTroubleshooting: true,
              isRecommended: false,
              supportLevel: ConnectionSupport.beta,
              instructionLink: 'INSTRUCTIONS_REMOTE_CONTROL.md',
              title: context.i18n.enablePairingProcess,
              description: context.i18n.pairingDescription,
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) async {
                if (value) {
                  await core.stopAllBleConnections();
                }
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
