import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/wifi_animation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../utils/requirements/android.dart';
import '../utils/requirements/multi.dart';

class ScanWidget extends StatefulWidget {
  const ScanWidget({super.key});

  @override
  State<ScanWidget> createState() => _ScanWidgetState();
}

class _ScanWidgetState extends State<ScanWidget> {
  List<PlatformRequirement>? _needsPermissions;

  @override
  void initState() {
    super.initState();

    core.connection.initialize();

    _checkRequirements();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needsPermissions != null && _needsPermissions!.isNotEmpty)
          Card(
            child: Basic(
              title: Text(
                'In order for BikeControl to search for nearby devices, please enable the following permissions:\n\n${_needsPermissions!.joinToString(transform: (e) => e.name, separator: '\n')}',
              ),
              trailing: isMobile
                  ? null
                  : PrimaryButton(
                      child: Text('Enable Permissions'),
                      onPressed: () async {
                        await openPermissionSheet(context, _needsPermissions!);
                        _checkRequirements();
                      },
                    ),
              subtitle: !isMobile
                  ? null
                  : PrimaryButton(
                      child: Text('Enable Permissions'),
                      onPressed: () async {
                        await openPermissionSheet(context, _needsPermissions!);
                        _checkRequirements();
                      },
                    ),
            ),
          )
        else
          ValueListenableBuilder(
            valueListenable: core.connection.isScanning,
            builder: (context, isScanning, widget) {
              if (isScanning) {
                return Column(
                  spacing: 22,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Text(
                            'Scanning for devices... Make sure they are powered on and in range and not connected to another device.',
                          ).small.muted,
                        ),
                        SmoothWifiAnimation(),
                      ],
                    ),
                    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows))
                      ValueListenableBuilder(
                        valueListenable: core.connection.isMediaKeyDetectionEnabled,
                        builder: (context, value, child) {
                          return Tooltip(
                            tooltip: (c) => TooltipContainer(
                              child: Text(
                                'Enable this option to allow BikeControl to detect bluetooth remotes.\nIn order to do so BikeControl needs to act as a media player.',
                              ),
                            ),
                            child: Checkbox(
                              state: value ? CheckboxState.checked : CheckboxState.unchecked,
                              trailing: Text("Enable Media Key Detection"),
                              onChanged: (change) {
                                core.connection.isMediaKeyDetectionEnabled.value = change == CheckboxState.checked;
                              },
                            ),
                          );
                        },
                      ),
                    OutlineButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
                        );
                      },
                      child: const Text("Show Troubleshooting Guide"),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    PrimaryButton(
                      onPressed: () {
                        core.connection.performScanning();
                      },
                      child: const Text("SCAN"),
                    ),
                  ],
                );
              }
            },
          ),
      ],
    );
  }

  Future<void> _checkRequirements() async {
    final List<PlatformRequirement> list;
    if (kIsWeb) {
      final availablity = await UniversalBle.getBluetoothAvailabilityState();
      if (availablity == AvailabilityState.unsupported) {
        list = [UnsupportedPlatform()];
      } else {
        list = [BluetoothTurnedOn()];
      }
    } else if (Platform.isMacOS) {
      list = [BluetoothTurnedOn()];
    } else if (Platform.isIOS) {
      list = [
        BluetoothTurnedOn(),
      ];
    } else if (Platform.isWindows) {
      list = [
        BluetoothTurnedOn(),
      ];
    } else if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
        if (deviceInfo.version.sdkInt <= 30)
          LocationRequirement()
        else ...[
          BluetoothScanRequirement(),
          BluetoothConnectRequirement(),
        ],
      ];
    } else {
      list = [UnsupportedPlatform()];
    }

    await Future.wait(list.map((e) => e.getStatus()));
    setState(() {
      _needsPermissions = list.where((e) => !e.status).toList();
      if (_needsPermissions!.isEmpty) {
        if (!kIsWeb) {
          core.connection.performScanning().catchError((e, s) {
            print("Error during scanning: $e\n$s");
          });
        }
      }
    });
  }
}
