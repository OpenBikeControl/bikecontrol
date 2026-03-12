import 'package:bike_control/pages/trainer.dart';
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
