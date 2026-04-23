import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Informational block shown above the Virtual Shifting Settings when the
/// user isn't Pro. Explains the daily limit and offers a Go Pro action.
class VirtualShiftingProNotice extends StatelessWidget {
  final String trainerAppName;

  const VirtualShiftingProNotice({super.key, required this.trainerAppName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(Icons.workspace_premium, color: Colors.orange, size: 18),
              Expanded(
                child: Text(
                  l10n.virtualShiftingProNote(trainerAppName),
                  style: TextStyle(fontSize: 12, color: cs.foreground),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Button.primary(
              onPressed: () => showGoProDialog(context),
              leading: const Icon(Icons.workspace_premium, size: 14),
              child: Text(l10n.goPro),
            ),
          ),
        ],
      ),
    );
  }
}
