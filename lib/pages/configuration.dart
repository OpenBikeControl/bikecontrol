import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/ui/colored_title.dart';

class ConfigurationPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const ConfigurationPage({super.key, required this.onUpdate});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final requirement = TargetRequirement();

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
        ColoredTitle(text: context.i18n.setupTrainer),
        Card(
          child: requirement.build(context, () {
            widget.onUpdate();
          })!,
        ),
      ],
    );
  }
}
