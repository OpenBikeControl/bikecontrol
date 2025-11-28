import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/remote.dart';
import 'package:swift_control/widgets/apps/mywhoosh_link_tile.dart';
import 'package:swift_control/widgets/apps/zwift_tile.dart';

class TrainerPage extends StatefulWidget {
  const TrainerPage({super.key});

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
      ],
    );
  }
}
