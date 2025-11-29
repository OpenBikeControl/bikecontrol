import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';

class OpenBikeProtocolTile extends StatefulWidget {
  const OpenBikeProtocolTile({super.key});

  @override
  State<OpenBikeProtocolTile> createState() => _OpenBikeProtocolTileState();
}

class _OpenBikeProtocolTileState extends State<OpenBikeProtocolTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.obpMdnsEmulator.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: core.obpMdnsEmulator.isConnected,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              title: 'Enable OpenBikeProtocol',
              description: isConnected != null
                  ? 'Connected to ${isConnected.appId}'
                  : 'OpenBikeProtocol allows compatible apps to connect directly to your trainer over the Network or Bluetooth.',
              requirements: [],
              onChange: (value) {
                if (!value) {
                  core.obpMdnsEmulator.stopServer();
                } else if (value) {
                  core.obpMdnsEmulator.startServer().catchError((e) {
                    showToast(
                      context: context,
                      builder: (c, overlay) => buildToast(
                        context,
                        overlay,
                        title: 'Error starting OpenBikeProtocol server.',
                      ),
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
