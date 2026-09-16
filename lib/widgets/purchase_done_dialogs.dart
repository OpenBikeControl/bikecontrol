import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/register_this_device.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// After a Base purchase: what Base covers and, above all, what it doesn't.
/// Twelve "bought Base, still 20-min trial" chats, refund demands and a
/// one-star review came from riders who found out the hard way.
Future<void> showPurchaseBaseDoneDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseBaseDoneTitle)),
            ],
          ),
          content: Text(l10n.purchaseBaseDoneBody),
          actions: [
            PrimaryButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text(l10n.gotIt),
            ),
          ],
        ),
      );
    },
  );
}

/// After a Pro purchase or restore that leaves Pro on the account but not on
/// this device: say so, and offer the registration right there instead of
/// leaving "Pro (unregistered device)" in the title bar as the only clue.
Future<void> showPurchaseProUnregisteredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) {
      final l10n = AppLocalizations.of(c);
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.purchaseProDoneTitle)),
            ],
          ),
          // Two buttons, one of them long in most languages: AlertDialog's
          // `actions` is a plain Row, so they live in the content instead,
          // where a Wrap gets a bounded width and can fall onto two lines.
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.purchaseProUnregisteredBody),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Button.secondary(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(l10n.close),
                  ),
                  RegisterThisDeviceButton(
                    onDone: (registered) {
                      if (registered && c.mounted) Navigator.of(c).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
