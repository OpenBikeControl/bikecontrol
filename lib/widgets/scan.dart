import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/app_localizations.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/wifi_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needsPermissions != null && _needsPermissions!.isNotEmpty)
          Card(
            child: Basic(
              title: Text(
                '${context.i18n.permissionsRequired}\n\n${_needsPermissions!.joinToString(transform: (e) => e.name, separator: '\n')}',
              ),
              trailing: isMobile
                  ? null
                  : PrimaryButton(
                      child: Text(context.i18n.enablePermissions),
                      onPressed: () async {
                        await openPermissionSheet(context, _needsPermissions!);
                        _checkRequirements();
                      },
                    ),
              subtitle: !isMobile
                  ? null
                  : PrimaryButton(
                      child: Text(context.i18n.enablePermissions),
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
                  spacing: 18,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(),
                    Row(
                      spacing: 14,
                      children: [
                        SmoothWifiAnimation(),
                        Expanded(
                          child: Text(context.i18n.scanningForDevices).small.muted,
                        ),
                      ],
                    ),
                    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows))
                      ValueListenableBuilder(
                        valueListenable: core.connection.isMediaKeyDetectionEnabled,
                        builder: (context, value, child) {
                          return Tooltip(
                            tooltip: (c) => TooltipContainer(
                              child: Text(context.i18n.mediaKeyDetectionTooltip),
                            ),
                            child: Checkbox(
                              state: value ? CheckboxState.checked : CheckboxState.unchecked,
                              trailing: Text(context.i18n.enableMediaKeyDetection),
                              onChanged: (change) {
                                core.connection.isMediaKeyDetectionEnabled.value = change == CheckboxState.checked;
                              },
                            ),
                          );
                        },
                      ),
                    SizedBox(),
                    OutlineButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
                        );
                      },
                      child: Text(context.i18n.showTroubleshootingGuide),
                    ),
                    OutlineButton(
                      onPressed: () {
                        launchUrlString(
                          'https://github.com/jonasbark/swiftcontrol/?tab=readme-ov-file#supported-devices',
                        );
                      },
                      child: Text(context.i18n.showSupportedControllers),
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
      setState(() {
        _needsPermissions = permissions;
      });
    });
  }
}
