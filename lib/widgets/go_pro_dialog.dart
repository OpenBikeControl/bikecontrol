import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shows a dialog prompting the user to upgrade to Pro.
///
/// [featureName] names the thing the rider just reached for. Pass it wherever
/// the entry point is an icon or a toggle: "Pro Feature" alone tells them the
/// price of something they never found out the name of.
///
/// Returns true if the user initiated a purchase, false otherwise.
Future<bool> showGoProDialog(BuildContext context, {String? featureName}) async {
  final iapManager = IAPManager.instance;

  final result = await showDialog<bool>(
    context: context,
    builder: (c) => Container(
      constraints: BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.crown, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(featureName ?? 'Pro Feature')),
          ],
        ),
        content: Text(AppLocalizations.of(c).thisFeatureIsOnlyAvailableWithPro),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(c.i18n.cancel),
          ),
          LoadingWidget(
            futureCallback: () async {
              await iapManager.purchaseSubscription(context);
              if (c.mounted) {
                Navigator.of(c).pop(true);
              }
            },
            renderChild: (isLoading, tap) => PrimaryButton(
              onPressed: tap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isLoading ? SmallProgressIndicator() : Icon(LucideIcons.crown, size: 16),
                  const SizedBox(width: 8),
                  Text(c.i18n.goPro),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}
