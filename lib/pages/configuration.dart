import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/requirements/multi.dart';

class ConfigurationPage extends StatelessWidget {
  final VoidCallback onUpdate;
  ConfigurationPage({super.key, required this.onUpdate});

  final requirement = TargetRequirement();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 26,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Basic(
          leading: Image.asset('icon.png', width: 64, height: 64),
          title: Text('Welcome to BikeControl!'),
          subtitle: Text.rich(
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
          ),
        ),
        Card(
          child: requirement.build(context, onUpdate)!,
        ),
      ],
    );
  }
}
