import 'package:prop/prop.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
              supportedActions: core.whooshLink.supportedActions,
              isEnabled: core.settings.getMyWhooshLinkEnabled(),
              type: ConnectionMethodType.network,
              title: context.i18n.connectUsingMyWhooshLink,
              instructionLink: 'INSTRUCTIONS_MYWHOOSH_LINK.md',
              description: isConnected
                  ? context.i18n.myWhooshLinkConnected
                  : isStarted
                  ? context.i18n.checkMyWhooshConnectionScreen
                  : context.i18n.myWhooshLinkDescriptionLocal,
              requirements: [],
              showTroubleshooting: true,
              onChange: (value) {
                core.settings.setMyWhooshLinkEnabled(value);
                if (!value) {
                  core.whooshLink.stopServer();
                } else if (value) {
                  buildToast(
                    navigatorKey.currentContext!,
                    title: AppLocalizations.of(context).myWhooshLinkInfo,
                    level: LogLevel.LOGLEVEL_INFO,
                    duration: Duration(seconds: 6),
                    closeTitle: 'Open',
                    onClose: () {
                      openDrawer(
                        context: context,
                        position: OverlayPosition.bottom,
                        builder: (c) => MarkdownPage(assetPath: 'INSTRUCTIONS_MYWHOOSH_LINK.md'),
                      );
                    },
                  );
                  core.connection.startMyWhooshServer().catchError((e, s) {
                    recordError(e, s, context: 'MyWhoosh Link Server');
                    core.settings.setMyWhooshLinkEnabled(false);
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
