import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
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
              title: context.i18n.connectUsingMyWhooshLink,
              instructionLink: 'https://github.com/jonasbark/swiftcontrol/blob/main/INSTRUCTIONS_IOS.md',
              description: isConnected
                  ? context.i18n.myWhooshLinkConnected
                  : isStarted
                  ? context.i18n.checkMyWhooshConnectionScreen
                  : core.actionHandler is RemoteActions
                  ? context.i18n.myWhooshLinkDescriptionRemote
                  : context.i18n.myWhooshLinkDescriptionLocal,
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
                      title: context.i18n.errorStartingMyWhooshLink,
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
