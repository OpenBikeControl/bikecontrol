import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/wifi_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
                    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows))
                      ValueListenableBuilder(
                        valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
                        builder: (context, value, child) {
                          return Tooltip(
                            tooltip: (c) => TooltipContainer(
                              child: Text(context.i18n.mediaKeyDetectionTooltip),
                            ),
                            child: Checkbox(
                              state: value ? CheckboxState.checked : CheckboxState.unchecked,
                              trailing: Expanded(child: Text(context.i18n.enableMediaKeyDetection)),
                              onChanged: (change) {
                                core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = change == CheckboxState.checked;
                              },
                            ),
                          );
                        },
                      ),
                    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && !core.settings.getShowOnboarding())
                      Checkbox(
                        state: core.settings.getPhoneSteeringEnabled()
                            ? CheckboxState.checked
                            : CheckboxState.unchecked,
                        trailing: Expanded(
                          child: Row(
                            spacing: 4,
                            children: [
                              Icon(InGameAction.navigateRight.icon!, size: 16),
                              Icon(InGameAction.navigateLeft.icon!, size: 16),
                              SizedBox(),
                              Expanded(child: Text(AppLocalizations.of(context).enableSteeringWithPhone)),
                            ],
                          ),
                        ),
                        onChanged: (change) {
                          core.settings.setPhoneSteeringEnabled(change == CheckboxState.checked);
                          core.connection.toggleGyroscopeSteering(change == CheckboxState.checked);
                          setState(() {});
                        },
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
