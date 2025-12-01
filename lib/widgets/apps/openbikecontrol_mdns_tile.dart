import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/app_localizations.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';

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
                    buildToast(
                      context,
                      title: context.i18n.errorStartingOpenBikeControlServer,
                    );
                  });
                }
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
