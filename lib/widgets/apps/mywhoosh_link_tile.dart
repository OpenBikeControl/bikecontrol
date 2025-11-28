import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MyWhooshLinkTile extends StatefulWidget {
  const MyWhooshLinkTile({super.key});

  @override
  State<MyWhooshLinkTile> createState() => _MywhooshLinkTileState();
}

class _MywhooshLinkTileState extends State<MyWhooshLinkTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: whooshLink.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: whooshLink.isConnected,
          builder: (context, isConnected, _) {
            final myWhooshExplanation = actionHandler is RemoteActions
                ? 'MyWhoosh Direct Connect allows you to do some additional features such as Emotes and turn directions.'
                : 'MyWhoosh Direct Connect is optional, but allows you to do some additional features such as Emotes and turn directions.';
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    return Checkbox(
                      state: isStarted ? CheckboxState.checked : CheckboxState.unchecked,
                      onChanged: (value) {
                        settings.setMyWhooshLinkEnabled(value == CheckboxState.checked);
                        if (value == CheckboxState.unchecked) {
                          whooshLink.stopServer();
                        } else if (value == CheckboxState.checked) {
                          connection.startMyWhooshServer().catchError((e) {
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
                        setState(() {});
                      },
                      trailing: Expanded(
                        child: Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Enable MyWhoosh Direct Connect'),
                                  if (isStarted) ...[
                                    Text(
                                      isConnected ? "Connected" : "Connecting to MyWhoosh...",

                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                  if (!isStarted)
                                    Text(
                                      myWhooshExplanation,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isStarted) SmallProgressIndicator(),
                            IconButton(
                              variance: ButtonVariance.ghost,
                              onPressed: () {
                                launchUrlString('https://www.youtube.com/watch?v=p8sgQhuufeI');
                              },
                              icon: Icon(Icons.help_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
