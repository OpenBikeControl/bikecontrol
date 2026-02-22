import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shows a dialog prompting the user to upgrade to Pro.
/// Returns true if the user initiated a purchase, false otherwise.
Future<bool> showGoProDialog(BuildContext context) async {
  final iapManager = IAPManager.instance;

  final result = await showDialog<bool>(
    context: context,
    builder: (c) => Container(
      constraints: BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Pro Feature'),
          ],
        ),
        content: Text('This feature is only available with Pro. Upgrade to Pro to unlock all features.'),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Cancel'),
          ),
          LoadingWidget(
            futureCallback: () async {
              await iapManager.purchaseSubscription(c);
              Navigator.of(c).pop(true);
            },
            renderChild: (isLoading, tap) => PrimaryButton(
              onPressed: tap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isLoading ? SmallProgressIndicator() : Icon(Icons.workspace_premium, size: 16),
                  const SizedBox(width: 8),
                  Text('Go Pro'),
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
