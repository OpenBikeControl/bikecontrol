import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LocalTile extends StatefulWidget {
  const LocalTile({super.key});

  @override
  State<LocalTile> createState() => _LocalTileState();
}

class _LocalTileState extends State<LocalTile> {
  bool? _isRunningAndroidService;
  bool _showAutoRotationWarning = false;
  bool _showMiuiWarning = false;
  StreamSubscription<bool>? _autoRotateStream;

  @override
  void initState() {
    super.initState();
    if (core.logic.canRunAndroidService) {
      core.logic.isAndroidServiceRunning().then((isRunning) {
        core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
        setState(() {
          _isRunningAndroidService = isRunning;
        });
      });
    }

    if (Platform.isAndroid) {
      DeviceAutoRotateChecker.checkAutoRotate().then((isEnabled) {
        if (!isEnabled) {
          setState(() {
            _showAutoRotationWarning = true;
          });
        }
      });
      _autoRotateStream = DeviceAutoRotateChecker.autoRotateStream.listen((isEnabled) {
        setState(() {
          _showAutoRotationWarning = !isEnabled;
        });
      });

      // Check if device is MIUI and using local accessibility service
      if (core.actionHandler is AndroidActions) {
        _checkMiuiDevice();
      }
    }
  }

  @override
  void dispose() {
    _autoRotateStream?.cancel();
    super.dispose();
  }

  Future<void> _checkMiuiDevice() async {
    try {
      // Don't show if user has dismissed the warning
      if (core.settings.getMiuiWarningDismissed()) {
        return;
      }

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final isMiui =
          deviceInfo.manufacturer.toLowerCase() == 'xiaomi' ||
          deviceInfo.brand.toLowerCase() == 'xiaomi' ||
          deviceInfo.brand.toLowerCase() == 'redmi' ||
          deviceInfo.brand.toLowerCase() == 'poco';
      if (isMiui && mounted) {
        setState(() {
          _showMiuiWarning = true;
        });
      }
    } catch (e) {
      // Silently fail if device info is not available
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      // show warning only for android when using local accessibility service
      if (_showAutoRotationWarning)
        Warning(
          important: false,
          children: [
            Text(context.i18n.enableAutoRotation),
          ],
        ),
      if (_showMiuiWarning)
        Warning(
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(context.i18n.miuiDeviceDetected).bold,
                ),
                IconButton.destructive(
                  icon: Icon(Icons.close),
                  onPressed: () async {
                    await core.settings.setMiuiWarningDismissed(true);
                    setState(() {
                      _showMiuiWarning = false;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              context.i18n.miuiWarningDescription,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              context.i18n.miuiEnsureProperWorking,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              context.i18n.miuiDisableBatteryOptimization,
              style: TextStyle(fontSize: 14),
            ),
            Text(
              context.i18n.miuiEnableAutostart,
              style: TextStyle(fontSize: 14),
            ),
            Text(
              context.i18n.miuiLockInRecentApps,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            OutlineButton(
              onPressed: () async {
                final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              leading: Icon(Icons.open_in_new),
              child: Text(context.i18n.viewDetailedInstructions),
            ),
          ],
        ),
      if (_isRunningAndroidService == false)
        Warning(
          children: [
            Text(context.i18n.accessibilityServiceNotRunning).xSmall,
            SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: OutlineButton(
                    child: Text('dontkillmyapp.com'),
                    onPressed: () {
                      launchUrlString('https://dontkillmyapp.com/');
                    },
                  ),
                ),
                IconButton.secondary(
                  onPressed: () {
                    core.logic.isAndroidServiceRunning().then((isRunning) {
                      core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
                      setState(() {
                        _isRunningAndroidService = isRunning;
                      });
                    });
                  },
                  icon: Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
    ];
    return ConnectionMethod(
      isEnabled: core.settings.getLocalEnabled(),
      type: ConnectionMethodType.local,
      showTroubleshooting: true,
      instructionLink: 'INSTRUCTIONS_LOCAL.md',
      title: context.i18n.controlAppUsingModes(
        core.settings.getTrainerApp()?.name ?? '',
        core.actionHandler.supportedModes.joinToString(transform: (e) => e.name.capitalize()),
      ),
      description: context.i18n.enableKeyboardMouseControl(core.settings.getTrainerApp()?.name ?? ''),
      requirements: core.permissions.getLocalControlRequirements(),
      isStarted: core.logic.canRunAndroidService ? _isRunningAndroidService == true : core.settings.getLocalEnabled(),
      onChange: (value) {
        core.settings.setLocalEnabled(value);
        setState(() {});
        if (core.logic.canRunAndroidService) {
          core.logic.isAndroidServiceRunning().then((isRunning) {
            core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
            setState(() {
              _isRunningAndroidService = isRunning;
            });
          });
        } else {
          core.connection.signalNotification(LogNotification('Local Control: $value'));
        }
      },
      additionalChild: children.isNotEmpty
          ? Column(
              children: children,
            )
          : null,
    );
  }
}
