import 'package:bike_control/main.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LocalTile extends StatefulWidget {
  final bool small;
  const LocalTile({super.key, required this.small});

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
        core.local.isConnected.value = isRunning;
        core.local.isStarted.value = isRunning;
        setState(() {
          _isRunningAndroidService = isRunning;
        });
      });
    } else {
      core.local.isStarted.value = core.settings.getLocalEnabled();
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
                Icon(LucideIcons.triangleAlert),
                SizedBox(width: 8),
                Expanded(
                  child: Text(context.i18n.miuiDeviceDetected).bold,
                ),
                BkIconButton.destructive(
                  icon: Icon(LucideIcons.x),
                  label: context.i18n.a11yDismiss,
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
              style: context.typography.small,
            ),
            SizedBox(height: 8),
            Text(
              context.i18n.miuiEnsureProperWorking,
              style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              context.i18n.miuiDisableBatteryOptimization,
              style: context.typography.small,
            ),
            Text(
              context.i18n.miuiEnableAutostart,
              style: context.typography.small,
            ),
            Text(
              context.i18n.miuiLockInRecentApps,
              style: context.typography.small,
            ),
            SizedBox(height: 12),
            OutlineButton(
              onPressed: () async {
                final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              leading: Icon(LucideIcons.externalLink),
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
                BkIconButton.secondary(
                  label: context.i18n.a11yRefresh,
                  onPressed: () {
                    core.logic.isAndroidServiceRunning().then((isRunning) {
                      core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
                      setState(() {
                        _isRunningAndroidService = isRunning;
                      });
                    });
                  },
                  icon: Icon(LucideIcons.refreshCw),
                ),
              ],
            ),
          ],
        ),
    ];
    return ConnectionMethod(
      trainerConnection: core.local,
      isEnabled: core.settings.getLocalEnabled(),
      isRecommended: !core.logic.hasOfficialConnectionMethods,
      showTroubleshooting: true,
      small: widget.small,
      instructionLink: 'INSTRUCTIONS_LOCAL.md',
      title: context.i18n.controlAppUsingModes(
        shownTrainerAppName(core.settings.getTrainerApp()?.name ?? ''),
      ),
      description: context.i18n.enableKeyboardMouseControl(shownTrainerAppName(core.settings.getTrainerApp()?.name ?? '')),
      requirements: core.permissions.getLocalControlRequirements(),
      onChange: (value) {
        core.settings.setLocalEnabled(value);
        setState(() {});
        if (core.logic.canRunAndroidService) {
          core.logic.isAndroidServiceRunning().then((isRunning) {
            core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
            core.local.isStarted.value = isRunning;
            core.local.isConnected.value = isRunning;
            setState(() {
              _isRunningAndroidService = isRunning;
            });
          });
        } else {
          core.local.isStarted.value = value;
          core.local.isConnected.value = value;
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
