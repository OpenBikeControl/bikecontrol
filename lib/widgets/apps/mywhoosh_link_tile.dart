import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';

class MyWhooshLinkTile extends StatefulWidget {
  const MyWhooshLinkTile({super.key});

  @override
  State<MyWhooshLinkTile> createState() => _MywhooshLinkTileState();
}

class _MywhooshLinkTileState extends State<MyWhooshLinkTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.whooshLink.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: core.whooshLink.isConnected,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              title: 'Connect over MyWhoosh "Link"',
              instructionLink: 'https://github.com/jonasbark/swiftcontrol/blob/main/INSTRUCTIONS_IOS.md',
              description: isConnected
                  ? 'MyWhoosh "Link" connected'
                  : isStarted
                  ? 'Check the connection screen in MyWhoosh to see if "Link" is connected.'
                  : core.actionHandler is RemoteActions
                  ? 'Allows you to connect to MyWhoosh over the network. The MyWhoosh Link companion app must NOT be running at the same time.'
                  : 'Optional - allows you to do some additional features such as Emotes and turn directions. The MyWhoosh Link companion app must NOT be running at the same time.',
              requirements: [],
              showTroubleshooting: true,
              onChange: (value) {
                core.settings.setMyWhooshLinkEnabled(value);
                if (!value) {
                  core.whooshLink.stopServer();
                } else if (value) {
                  core.connection.startMyWhooshServer().catchError((e) {
                    buildToast(
                      context,
                      title:
                          'Error starting MyWhoosh Link server. Please make sure the "MyWhoosh Link" app is not already running on this device.',
                    );
                  });
                }
              },
              isStarted: isStarted,
              isConnected: isConnected,
            );
          },
        );
      },
    );
  }
}
