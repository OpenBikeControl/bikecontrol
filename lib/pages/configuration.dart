import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/multi.dart';

class ConfigurationPage extends StatefulWidget {
  final VoidCallback onUpdate;
  ConfigurationPage({super.key, required this.onUpdate});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final requirement = TargetRequirement();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 26,
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
        Card(
          child: requirement.build(context, () {
            setState(() {});
          })!,
        ),
        PrimaryButton(
          onPressed: settings.getTrainerApp() != null && settings.getLastTarget() != null
              ? () {
                  widget.onUpdate();
                }
              : null,
          child: Text('Continue'),
        ),
      ],
    );
  }
}
