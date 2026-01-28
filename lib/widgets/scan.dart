import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/wifi_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/requirements/platform.dart';

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

    _checkRequirements();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_needsPermissions != null && _needsPermissions!.isNotEmpty)
          Card(
            child: Basic(
              title: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.i18n.permissionsRequired).xSmall,
                  ..._needsPermissions!.map((e) => Text(e.name).li),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: PrimaryButton(
                  child: Text(context.i18n.enablePermissions),
                  onPressed: () async {
                    await openPermissionSheet(context, _needsPermissions!);
                    _checkRequirements();
                  },
                ),
              ),
            ),
          )
        else
          ValueListenableBuilder(
            valueListenable: core.connection.isScanning,
            builder: (context, isScanning, widget) {
              if (isScanning) {
                return Column(
                  spacing: 18,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (core.connection.controllerDevices.isEmpty)
                      Column(
                        spacing: 14,
                        children: [
                          SizedBox(),
                          SmoothWifiAnimation(),
                          Text(
                            context.i18n.scanningForDevices,
                            textAlign: TextAlign.center,
                          ).small.muted,
                        ],
                      ),
                    SizedBox(),
                  ],
                );
              } else {
                return Row(
                  children: [
                    PrimaryButton(
                      onPressed: () {
                        core.connection.performScanning();
                      },
                      child: Text(context.i18n.scan),
                    ),
                  ],
                );
              }
            },
          ),
      ],
    );
  }

  void _checkRequirements() {
    core.permissions.getScanRequirements().then((permissions) {
      if (!mounted) return;
      setState(() {
        _needsPermissions = permissions;
      });
      if (permissions.isEmpty && !kIsWeb) {
        core.connection.performScanning();
      }
    });
  }
}
