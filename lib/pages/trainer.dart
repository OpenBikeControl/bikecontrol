import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:device_auto_rotate_checker/device_auto_rotate_checker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/gen/l10n.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/configuration.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:swift_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:swift_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:swift_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:swift_control/widgets/apps/zwift_mdns_tile.dart';
import 'package:swift_control/widgets/apps/zwift_tile.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:swift_control/widgets/ui/warning.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart' show launchUrlString;
import 'package:wakelock_plus/wakelock_plus.dart';

class TrainerPage extends StatefulWidget {
  final VoidCallback onUpdate;
  final VoidCallback goToNextPage;
  const TrainerPage({super.key, required this.onUpdate, required this.goToNextPage});

  @override
  State<TrainerPage> createState() => _TrainerPageState();
}

class _TrainerPageState extends State<TrainerPage> with WidgetsBindingObserver {
  bool? _isRunningAndroidService;
  bool _showAutoRotationWarning = false;
  bool _showMiuiWarning = false;
  StreamSubscription<bool>? _autoRotateStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // keep screen on - this is required for iOS to keep the bluetooth connection alive
    if (!screenshotMode) {
      WakelockPlus.enable();
    }

    if (!kIsWeb) {
      if (core.logic.showForegroundMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // show snackbar to inform user that the app needs to stay in foreground
          buildToast(context, title: AppLocalizations.current.touchSimulationForegroundMessage);
        });
      }

      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _autoRotateStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (core.logic.showForegroundMessage) {
        UniversalBle.getBluetoothAvailabilityState().then((state) {
          if (state == AvailabilityState.poweredOn && mounted) {
            final requirement = RemoteRequirement();
            requirement.reconnect();
            buildToast(context, title: AppLocalizations.current.touchSimulationForegroundMessage);
          }
        });
      }
    }
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          ConfigurationPage(
            onUpdate: () {
              setState(() {});
              widget.onUpdate();
            },
          ),
          if (core.settings.getTrainerApp() != null) ...[
            // show warning only for android when using local accessibility service
            if (_showAutoRotationWarning && _isRunningAndroidService == true)
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
                  IconButton.secondary(
                    onPressed: () async {
                      final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: Icon(Icons.open_in_new),
                    trailing: Text(context.i18n.viewDetailedInstructions),
                  ),
                ],
              ),

            SizedBox(height: 8),
            if (core.logic.showObpBluetoothEmulator ||
                core.logic.showObpMdnsEmulator ||
                core.logic.showLocalControl ||
                core.logic.showMyWhooshLink ||
                core.logic.showZwiftBleEmulator ||
                core.logic.showZwiftMsdnEmulator ||
                core.logic.showMyWhooshLink)
              ColoredTitle(
                text: context.i18n.recommendedConnectionMethods,
              ),

            if (core.logic.showObpMdnsEmulator)
              Card(
                child: OpenBikeControlMdnsTile(),
              ),
            if (core.logic.showObpBluetoothEmulator)
              Card(
                child: OpenBikeControlBluetoothTile(),
              ),

            if (core.logic.showMyWhooshLink) Card(child: MyWhooshLinkTile()),
            if (core.logic.showZwiftBleEmulator)
              Card(
                child: ZwiftTile(
                  onUpdate: () {
                    core.connection.signalNotification(
                      LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
                    );
                    setState(() {});
                  },
                ),
              ),
            if (core.logic.showZwiftMsdnEmulator)
              Card(
                child: ZwiftMdnsTile(
                  onUpdate: () {
                    core.connection.signalNotification(
                      LogNotification('Zwift Emulator status changed to ${core.zwiftEmulator.isConnected.value}'),
                    );
                  },
                ),
              ),
            if (core.logic.showLocalControl)
              Card(
                child: ConnectionMethod(
                  showTroubleshooting: true,
                  title: context.i18n.controlAppUsingModes(
                    core.settings.getTrainerApp()?.name ?? '',
                    core.actionHandler.supportedModes.joinToString(transform: (e) => e.name),
                  ),
                  description: context.i18n.enableKeyboardMouseControl(core.settings.getTrainerApp()?.name ?? ''),
                  requirements: core.permissions.getLocalControlRequirements(),
                  isStarted: core.logic.canRunAndroidService ? _isRunningAndroidService == true : null,
                  onChange: (value) {
                    if (core.logic.canRunAndroidService) {
                      core.logic.canRunAndroidService.then((isRunning) {
                        core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
                        setState(() {
                          _isRunningAndroidService = isRunning;
                        });
                      });
                    }
                  },
                  additionalChild: _isRunningAndroidService == false
                      ? Warning(
                          children: [
                            Text(context.i18n.accessibilityServiceNotRunning).xSmall,
                            Row(
                              spacing: 8,
                              children: [
                                Expanded(
                                  child: LinkButton(
                                    child: Text('dontkillmyapp.com'),
                                    onPressed: () {
                                      launchUrlString('https://dontkillmyapp.com/');
                                    },
                                  ),
                                ),
                                IconButton.secondary(
                                  onPressed: () {
                                    core.logic.isAndroidServiceRunning().then((
                                      isRunning,
                                    ) {
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
                        )
                      : null,
                ),
              ),
            if (core.logic.showRemote) ...[
              SizedBox(height: 8),
              ColoredTitle(text: context.i18n.otherConnectionMethods),
              Card(
                child: RemoteRequirement().build(context, () {
                  core.connection.signalNotification(
                    LogNotification('Remote Control changed to ${(core.actionHandler as RemoteActions).isConnected}'),
                  );
                })!,
              ),
            ],

            SizedBox(),
            PrimaryButton(
              child: Text(context.i18n.adjustControllerButtons),
              onPressed: () {
                widget.goToNextPage();
              },
            ),
          ],
        ],
      ),
    );
  }
}
