import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LinkDevice extends BaseDevice {
  String identifier;

  LinkDevice(this.identifier) : super('MyWhoosh Link', availableButtons: []);

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
                        connection.startMyWhooshServer();
                      }
                      setState(() {});
                    },
                    title: Text('Enable MyWhoosh Link'),
                    subtitle: Row(
                      spacing: 12,
                      children: [
                        if (!settings.getMyWhooshLinkEnabled())
                          Text('Disabled')
                        else ...[
                          Text(
                            isConnected ? "Connected" : "Connecting to MyWhoosh...",
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
