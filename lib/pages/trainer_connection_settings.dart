import 'package:bike_control/pages/trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerConnectionSettingsPage extends StatefulWidget {
  const TrainerConnectionSettingsPage({super.key});

  @override
  State<TrainerConnectionSettingsPage> createState() => _TrainerConnectionSettingsPageState();
}

class _TrainerConnectionSettingsPageState extends State<TrainerConnectionSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            'Connection Settings',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            if (core.settings.getTrainerApp() is Rouvy || core.settings.getTrainerApp() is TrainingPeaks)
              Builder(
                builder: (context) {
                  return IconButton.ghost(
                    icon: Icon(Icons.more_vert, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
                    onPressed: () {
                      showDropdown(
                        context: context,
                        builder: (c) => DropdownMenu(
                          children: [
                            MenuCheckbox(
                              value: core.settings.getShowExperimental(),
                              child: Text('Show experimental'),
                              onChanged: (c, value) {
                                core.settings.setShowExperimental(value);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        Divider(),
      ],
      child: TrainerPage(
        onUpdate: () {
          setState(() {});
        },
        goToNextPage: () {},
        isMobile: false,
      ),
    );
  }

  // ── Target Device ────────────────────────────────────────────────────
}
