import 'dart:io';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (settings.getLastTarget()?.connectionType == ConnectionType.local &&
            (Platform.isMacOS || Platform.isWindows || Platform.isAndroid))
          Card(
            child: ConnectionMethod(
              title: 'Control ${settings.getTrainerApp()?.name} using Keyboard / Mouse / Touch',
              description:
                  'Enable keyboard and mouse control for better interaction with ${settings.getTrainerApp()?.name}.',
              requirements: [Platform.isAndroid ? AccessibilityRequirement() : KeyboardRequirement()],
              onChange: (value) {},
            ),
          ),
        if (settings.getTrainerApp() is MyWhoosh && whooshLink.isCompatible(settings.getLastTarget()!))
          Card(child: MyWhooshLinkTile()),
        if (settings.getTrainerApp()?.supportsZwiftEmulation == true)
          Card(
            child: ZwiftTile(
              onUpdate: () {
                setState(() {});
              },
            ),
          ),

        if (settings.getLastTarget() != Target.thisDevice) Card(child: RemoteRequirement().build(context, () {})!),

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
