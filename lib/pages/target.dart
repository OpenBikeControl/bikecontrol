import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/requirements/multi.dart';

class TargetPage extends StatelessWidget {
  final VoidCallback onUpdate;
  TargetPage({super.key, required this.onUpdate});

  final requirement = TargetRequirement();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        Gap(16),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Image.asset('icon.png', width: 64, height: 64),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to BikeControl!').medium,
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 140),

                  child: Text.rich(
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
              ],
            ),
          ],
        ),
        requirement.build(context, onUpdate)!,
      ],
    );
  }
}
