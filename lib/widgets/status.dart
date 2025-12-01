import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StatusWidget extends StatefulWidget {
  const StatusWidget({super.key});

  @override
  State<StatusWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  bool? _isRunningAndroidService;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid && core.actionHandler is AndroidActions) {
      (core.actionHandler as AndroidActions).accessibilityHandler.isRunning().then((isRunning) {
        setState(() {
          _isRunningAndroidService = isRunning;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = core.actionHandler is RemoteActions && isAdvertisingPeripheral;
    final isZwift = core.logic.showZwiftEmulator;
    return Card(
      child: Column(
        spacing: 8,
        children: [
          if (core.connection.controllerDevices.isEmpty)
            _Status(color: Colors.red, text: 'No connected controllers')
          else
            _Status(
              color: Colors.green,
              text:
                  '${core.connection.controllerDevices.length == 1 ? 'Controller connected' : '${core.connection.controllerDevices.length} controllers connected'} ',
            ),
          if (core.whooshLink.isCompatible(core.settings.getLastTarget() ?? Target.thisDevice) &&
              core.settings.getMyWhooshLinkEnabled() &&
              !isZwift)
            _Status(
              color: core.whooshLink.isConnected.value
                  ? Colors.green
                  : Platform.isAndroid
                  ? Colors.yellow
                  : Colors.red,
              text:
                  'MyWhoosh Direct Connect ${core.whooshLink.isConnected.value
                      ? "connected"
                      : Platform.isAndroid
                      ? "not connected (optional)"
                      : "not connected"}',
            ),

          if (isRemote)
            _Status(
              color: (core.actionHandler as RemoteActions).isConnected ? Colors.green : Colors.red,
              text: 'Remote ${(core.actionHandler as RemoteActions).isConnected ? "connected" : "not connected"}',
            ),
          if (isZwift)
            _Status(
              color: core.zwiftEmulator.isConnected.value ? Colors.green : Colors.red,
              text: 'Zwift Emulation ${core.zwiftEmulator.isConnected.value ? "connected" : "not connected"}',
            ),
          if (!isRemote && !isZwift && !screenshotMode && core.settings.getLastTarget() != Target.thisDevice)
            _Status(
              color: Colors.red,
              text: 'Not connected to a remote device',
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
                          child: LinkButton(
                            child: Text('https://dontkillmyapp.com/'),
                            onPressed: () {
                              launchUrlString('https://dontkillmyapp.com/');
                            },
                          ),
                        ),
                        IconButton.secondary(
                          onPressed: () {
                            (core.actionHandler as AndroidActions).accessibilityHandler.isRunning().then((
                              isRunning,
                            ) {
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
