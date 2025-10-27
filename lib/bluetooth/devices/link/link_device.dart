import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/loading_widget.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('MyWhoosh Link: ${isConnected ? 'Connected' : 'Not connected'}'),
        Row(
          children: [
            if (!isConnected)
              LoadingWidget(
                futureCallback: () => connection.startMyWhooshServer(),
                renderChild: (isLoading, tap) => ValueListenableBuilder(
                  valueListenable: whooshLink.isConnected,
                  builder: (c, isConnected, _) => TextButton(
                    onPressed: !isConnected ? tap : null,
                    child: isLoading || (!isConnected && whooshLink.isStarted.value)
                        ? SmallProgressIndicator()
                        : Text('Connect'),
                  ),
                ),
              ),

            PopupMenuButton(
              itemBuilder: (c) => [
                if (isConnected)
                  PopupMenuItem(
                    child: Text('Disconnect'),
                    onTap: () {
                      connection.disconnect(this, forget: true);
                    },
                  )
                else
                  PopupMenuItem(
                    child: Text('Stop'),
                    onTap: () {
                      whooshLink.stopServer();
                    },
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
