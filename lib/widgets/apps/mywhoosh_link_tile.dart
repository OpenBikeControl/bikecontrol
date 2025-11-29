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
              title: 'Enable MyWhoosh Direct Connect',
              instructionLink: 'https://www.youtube.com/watch?v=p8sgQhuufeI',
              description: core.actionHandler is RemoteActions
                  ? 'MyWhoosh Direct Connect allows you to do some additional features such as Emotes and turn directions.'
                  : 'MyWhoosh Direct Connect is optional, but allows you to do some additional features such as Emotes and turn directions.',
              requirements: [],
              onChange: (value) {
                core.settings.setMyWhooshLinkEnabled(value);
                if (!value) {
                  core.whooshLink.stopServer();
                } else if (value) {
                  core.connection.startMyWhooshServer().catchError((e) {
                    showToast(
                      context: context,
                      builder: (c, overlay) => buildToast(
                        context,
                        overlay,
                        title:
                            'Error starting MyWhoosh Direct Connect server. Please make sure the "MyWhoosh Link" app is not already running on this device.',
                      ),
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
