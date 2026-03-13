import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerLabel extends StatelessWidget {
  final String name;
  const TrainerLabel({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Button.fixed(
      onPressed: () {
        context.push(TrainerConnectionSettingsPage());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(LucideIcons.monitor, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
            Text(
              name.split(' ').first,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
