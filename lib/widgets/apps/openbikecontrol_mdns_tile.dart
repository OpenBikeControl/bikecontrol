import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/core.dart';
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
              title: 'Connect directly over Network',
              description: isConnected != null
                  ? 'Connected to ${isConnected.appId}'
                  : isStarted
                  ? 'Choose BikeControl in the connection screen.'
                  : "Lets ${core.settings.getTrainerApp()?.name} connect directly over the Network. Choose BikeControl in the connection screen.",
              requirements: [],
              onChange: (value) {
                core.settings.setObpMdnsEnabled(value);
                if (!value) {
                  core.obpMdnsEmulator.stopServer();
                } else if (value) {
                  core.obpMdnsEmulator.startServer().catchError((e) {
                    buildToast(
                      context,
                      title: 'Error starting OpenBikeControl server.',
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
