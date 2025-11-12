import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../small_progress_indicator.dart';

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
            return StatefulBuilder(
              builder: (context, setState) {
                final myWhooshExplanation = actionHandler is RemoteActions
                    ? 'MyWhoosh Direct Connect allows you to do some additional features such as Emotes and turn directions.'
                    : 'MyWhoosh Direct Connect is optional, but allows you to do some additional features such as Emotes and turn directions.';
                return Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isStarted,
                        onChanged: (value) {
                          settings.setMyWhooshLinkEnabled(value);
                          if (!value) {
                            whooshLink.stopServer();
                          } else if (value) {
                            connection.startMyWhooshServer().catchError((e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error starting MyWhoosh Direct Connect server. Please make sure the "MyWhoosh Link" app is not already running on this device.',
                                  ),
                                ),
                              );
                            });
                          }
                          setState(() {});
                        },
                        title: Text('Enable MyWhoosh Direct Connect'),
                        subtitle: Row(
                          spacing: 12,
                          children: [
                            if (!isStarted)
                              Expanded(
                                child: Text(
                                  myWhooshExplanation,
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                            else ...[
                              Expanded(
                                child: Text(
                                  isConnected ? "Connected" : "Connecting to MyWhoosh...\n$myWhooshExplanation",

                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              if (isStarted) SmallProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        launchUrlString('https://www.youtube.com/watch?v=p8sgQhuufeI');
                      },
                      icon: Icon(Icons.help_outline),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
