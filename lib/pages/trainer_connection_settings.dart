import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerConnectionSettingsPage extends StatefulWidget {
  const TrainerConnectionSettingsPage({super.key});

  @override
  State<TrainerConnectionSettingsPage> createState() => _TrainerConnectionSettingsPageState();
}

class _TrainerConnectionSettingsPageState extends State<TrainerConnectionSettingsPage> {
  bool get _missingTarget {
    final trainerApp = core.settings.getTrainerApp();
    return trainerApp != null && trainerApp is! BikeControl && core.settings.getLastTarget() == null;
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final trainerName = core.settings.getTrainerApp()?.name ?? l10n.yourTrainerApp;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noTargetSelected),
        content: Text(l10n.needsTargetLeavePrompt(trainerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.stay),
          ),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_missingTarget,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmLeave();
        if (!shouldLeave) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        headers: [
          AppBar(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: [
              IconButton.ghost(
                icon: Icon(LucideIcons.arrowLeft, size: 24),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
            title: Text(
              AppLocalizations.of(context).connectionSettings,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
            ),
            trailing: [
              if (core.settings.getTrainerApp()?.connections.any((e) => e.$2 == ConnectionSupport.experimental) ??
                  false)
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
                                child: Text(AppLocalizations.of(context).showExperimental),
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
                onPressed: () => Navigator.of(context).maybePop(),
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
      ),
    );
  }

  // ── Target Device ────────────────────────────────────────────────────
}
