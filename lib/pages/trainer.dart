import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:swift_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:swift_control/widgets/apps/zwift_tile.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';

class TrainerPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const TrainerPage({super.key, required this.onUpdate});

  @override
  State<TrainerPage> createState() => _TrainerPageState();
}

class _TrainerPageState extends State<TrainerPage> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      core.whooshLink.isStarted.addListener(() {
        if (mounted) setState(() {});
      });

      core.zwiftEmulator.isConnected.addListener(() {
        if (mounted) setState(() {});
      });

      if (core.settings.getZwiftEmulatorEnabled() && core.actionHandler.supportedApp?.supportsZwiftEmulation == true) {
        core.zwiftEmulator.startAdvertising(() {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (core.settings.getLastTarget()?.connectionType == ConnectionType.local &&
            (Platform.isMacOS || Platform.isWindows || Platform.isAndroid))
          Card(
            child: ConnectionMethod(
              title: 'Control ${core.settings.getTrainerApp()?.name} using Keyboard / Mouse / Touch',
              description:
                  'Enable keyboard and mouse control for better interaction with ${core.settings.getTrainerApp()?.name}.',
              requirements: [Platform.isAndroid ? AccessibilityRequirement() : KeyboardRequirement()],
              onChange: (value) {},
            ),
          ),
        if (core.settings.getTrainerApp() is MyWhoosh && core.whooshLink.isCompatible(core.settings.getLastTarget()!))
          Card(child: MyWhooshLinkTile()),
        if (core.settings.getTrainerApp()?.supportsZwiftEmulation == true)
          Card(
            child: ZwiftTile(
              onUpdate: () {
                setState(() {});
              },
            ),
          ),

        if (core.settings.getLastTarget() != Target.thisDevice) Card(child: RemoteRequirement().build(context, () {})!),

        PrimaryButton(
          child: Text('Adjust Controller Buttons'),
          onPressed: () {
            widget.onUpdate();
          },
        ),
      ],
    );
  }
}
