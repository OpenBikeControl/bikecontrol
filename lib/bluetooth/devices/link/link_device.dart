import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LinkDevice extends BaseDevice {
  String identifier;

  LinkDevice(this.identifier) : super('MyWhoosh Direct Connect', availableButtons: []);

  @override
  Future<void> connect() async {
    isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    super.disconnect();
    whooshLink.stopServer();
    isConnected = false;
  }

  @override
  Widget showInformation(BuildContext context) {
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
                    value: settings.getMyWhooshLinkEnabled(),
                    onChanged: (value) {
                      settings.setMyWhooshLinkEnabled(value);
                      if (!value) {
                        disconnect();
                        connection.disconnect(this, forget: true);
                      } else if (value) {
                        connection.startMyWhooshServer().catchError((e) {
                          actionStreamInternal.add(
                            LogNotification('Error starting MyWhoosh Direct Connect server: $e'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('There was a problem starting the connection. Try restarting your device.'),
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
                        if (!settings.getMyWhooshLinkEnabled())
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
                          if (!isConnected) SmallProgressIndicator(),
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
  }
}
