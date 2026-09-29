import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../main.dart';

class DeviceInfo extends StatelessWidget {
  final String title;
  final String value;
  final Widget? additionalInfo;
  final IconData icon;

  const DeviceInfo({super.key, required this.title, required this.icon, required this.value, this.additionalInfo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: screenshotMode ? 160 : null,
      height: screenshotMode ? 70 : null,
      child: Card(
        filled: true,
        padding: EdgeInsets.all(12),
        fillColor: Theme.of(context).colorScheme.background,
        child: Basic(
          title: Text(title).xSmall,
          subtitle: Row(
            children: [
              Text(
                value,
                style: context.typography.xSmall,
              ),
              ?additionalInfo,
            ],
          ),
          trailingAlignment: Alignment.centerRight,
          trailing: Icon(
            icon,
            color: icon == LucideIcons.triangleAlert || icon == LucideIcons.batteryWarning
                ? Theme.of(context).colorScheme.destructive
                : null,
          ),
        ),
      ),
    );
  }
}
