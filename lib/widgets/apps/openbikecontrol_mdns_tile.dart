import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';

class OpenBikeControlMdnsTile extends StatefulWidget {
  const OpenBikeControlMdnsTile({super.key});

  @override
  State<OpenBikeControlMdnsTile> createState() => _OpenBikeProtocolTileState();
}

class _OpenBikeProtocolTileState extends State<OpenBikeControlMdnsTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.obpMdnsEmulator.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: core.obpMdnsEmulator.isConnected,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              isEnabled: core.settings.getObpMdnsEnabled(),
              type: ConnectionMethodType.openBikeControl,
              title: context.i18n.connectDirectlyOverNetwork,
              description: isConnected != null
                  ? context.i18n.connectedTo(isConnected.appId)
                  : isStarted
                  ? context.i18n.chooseBikeControlInConnectionScreen
                  : context.i18n.letsAppConnectOverNetwork(core.settings.getTrainerApp()?.name ?? ''),
              requirements: [],
              onChange: (value) {
                core.settings.setObpMdnsEnabled(value);
                if (!value) {
                  core.obpMdnsEmulator.stopServer();
                } else if (value) {
                  core.obpMdnsEmulator.startServer().catchError((e) {
                    core.settings.setObpMdnsEnabled(false);
                    core.connection.signalNotification(
                      AlertNotification(
                        LogLevel.LOGLEVEL_ERROR,
                        context.i18n.errorStartingOpenBikeControlServer,
                      ),
                    );
                  });
                }
                setState(() {});
              },
              isStarted: isStarted,
              isConnected: isConnected != null,
            );
          },
        );
      },
    );
  }
}
