import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../utils/core.dart';

class ConfigurationPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const ConfigurationPage({super.key, required this.onUpdate});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final requirement = TargetRequirement();

  final _newSetup = core.settings.getTrainerApp() == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Need help? Click on the '),
              WidgetSpan(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Icon(Icons.help_outline),
                ),
              ),
              TextSpan(text: ' button on top and don\'t hesitate to contact us.'),
            ],
          ),
        ).small.muted,
        SizedBox(height: 4),
        if (core.settings.getTrainerApp() != null && !_newSetup)
          Accordion(
            items: [
              AccordionItem(
                trigger: AccordionTrigger(
                  child: Text(
                    'Change Trainer setup (${core.settings.getTrainerApp()!.name} on ${core.settings.getLastTarget()?.title})',
                  ).bold,
                ),
                content: Card(
                  child: requirement.build(context, () {
                    widget.onUpdate();
                  })!,
                ),
              ),
            ],
          )
        else ...[
          Text('Setup Trainer').bold,
          Card(
            child: requirement.build(context, () {
              widget.onUpdate();
            })!,
          ),
        ],
      ],
    );
  }
}
