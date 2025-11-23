import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StatusWidget extends StatefulWidget {
  const StatusWidget({super.key});

  @override
  State<StatusWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  bool? _isRunningAndroidService = null;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      (actionHandler as AndroidActions).accessibilityHandler.isRunning().then((isRunning) {
        setState(() {
          _isRunningAndroidService = isRunning;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          spacing: 8,
          children: [
            if (connection.controllerDevices.isEmpty)
              _Status(color: Colors.red, text: 'No connected controllers')
            else
              _Status(
                color: Colors.green,
                text:
                    '${connection.controllerDevices.length == 1 ? 'Controller connected' : '${connection.controllerDevices.length} controllers connected'} ',
              ),
            if (whooshLink.isCompatible(settings.getLastTarget() ?? Target.thisDevice) &&
                settings.getMyWhooshLinkEnabled())
              _Status(
                color: whooshLink.isConnected.value
                    ? Colors.green
                    : Platform.isAndroid
                    ? Colors.yellow
                    : Colors.red,
                text: 'MyWhoosh Direct Connect ${whooshLink.isConnected.value ? "connected" : "not connected"}',
              ),

            if (actionHandler is RemoteActions && isAdvertisingPeripheral)
              _Status(
                color: (actionHandler as RemoteActions).isConnected ? Colors.green : Colors.red,
                text: 'Remote ${(actionHandler as RemoteActions).isConnected ? "connected" : "not connected"}',
              ),
            if (settings.getTrainerApp()?.supportsZwiftEmulation == true)
              _Status(
                color: zwiftEmulator.isConnected.value ? Colors.green : Colors.red,
                text: 'Zwift Emulation ${zwiftEmulator.isConnected.value ? "connected" : "not connected"}',
              ),
            if (_isRunningAndroidService != null)
              _Status(
                color: _isRunningAndroidService! ? Colors.green : Colors.red,
                text: 'Accessibility service is ${_isRunningAndroidService! ? 'available' : 'not available'}',
                trailing: !_isRunningAndroidService!
                    ? Row(
                        spacing: 8,
                        children: [
                          Text('Follow instructions at'),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(0, 0)),
                              child: Text('https://dontkillmyapp.com/'),
                              onPressed: () {
                                launchUrlString('https://dontkillmyapp.com/');
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              (actionHandler as AndroidActions).accessibilityHandler.isRunning().then((isRunning) {
                                setState(() {
                                  _isRunningAndroidService = isRunning;
                                });
                              });
                            },
                            icon: Icon(Icons.refresh),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final Color color;
  final String text;
  final Widget? trailing;
  const _Status({super.key, required this.color, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.circle, color: color, size: 16),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
        if (trailing != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16 + 8.0),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}
