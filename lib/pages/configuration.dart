import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';

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
              TextSpan(text: '${context.i18n.needHelpClickHelp} '),
              WidgetSpan(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Icon(Icons.help_outline),
                ),
              ),
              TextSpan(text: ' ${context.i18n.needHelpDontHesitate}'),
            ],
          ),
        ).small.muted,
        SizedBox(height: 4),
        if (core.settings.getTrainerApp() != null && !_newSetup)
          Accordion(
            items: [
              AccordionItem(
                trigger: AccordionTrigger(
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: ColoredTitle(
                          text: context.i18n.trainerSetup(
                            core.settings.getTrainerApp()!.name,
                            core.settings.getLastTarget()?.getTitle(context) ?? '',
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: PrimaryButton(
                          child: Text(context.i18n.adjust),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
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
          ColoredTitle(text: context.i18n.setupTrainer),
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
