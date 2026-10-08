import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Asks what happens to the rider's own button mapping when they pick
/// [selectedApp], if there's anything to ask (see [customKeymapToConfirmFor]).
///
/// Returns [KeymapSwitchChoice.keepCustom] without a dialog when nothing needs
/// deciding, and null when the rider dismissed the dialog — the caller then
/// leaves the trainer app as it was.
Future<KeymapSwitchChoice?> askKeymapForTrainerApp(BuildContext context, SupportedApp selectedApp) async {
  final profile = customKeymapToConfirmFor(selectedApp);
  if (profile == null) return KeymapSwitchChoice.keepCustom;
  return showDialog<KeymapSwitchChoice>(
    context: context,
    builder: (c) {
      final l = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AlertDialog(
          title: Text(l.keymapSwitchTitle),
          content: Text(l.keymapSwitchBody(profile, selectedApp.name)),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                Button.secondary(
                  onPressed: () => Navigator.of(c).pop(KeymapSwitchChoice.keepCustom),
                  child: Text(l.keymapSwitchKeepCustom),
                ),
                PrimaryButton(
                  onPressed: () => Navigator.of(c).pop(KeymapSwitchChoice.useAppButtons),
                  child: Text(l.keymapSwitchUseAppButtons(selectedApp.name)),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// [applyTrainerAppSelection] after asking about the rider's own mapping.
/// False when the rider dismissed the question and nothing changed.
Future<bool> pickTrainerApp(BuildContext context, SupportedApp selectedApp) async {
  final choice = await askKeymapForTrainerApp(context, selectedApp);
  if (choice == null) return false;
  await applyTrainerAppSelection(selectedApp, keymapChoice: choice);
  return true;
}
