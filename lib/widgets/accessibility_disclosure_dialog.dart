import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/utils/i18n_extension.dart';

class AccessibilityDisclosureDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const AccessibilityDisclosureDialog({
    super.key,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation from dismissing dialog
      child: AlertDialog(
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(context.i18n.accessibilityServicePermissionRequired),
        ),
        padding: EdgeInsets.symmetric(vertical: 16),
        content: SizedBox(
          height: 560,
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.i18n.accessibilityServiceExplanation,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(context.i18n.whyPermissionNeeded),
                  SizedBox(height: 8),
                  Text(context.i18n.accessibilityReasonTouch.replaceAll('• ', '')).li,
                  Text(context.i18n.accessibilityReasonWindow.replaceAll('• ', '')).li,
                  Text(context.i18n.accessibilityReasonControl.replaceAll('• ', '')).li,
                  SizedBox(height: 16),
                  Text(
                    context.i18n.howBikeControlUsesPermission,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(context.i18n.accessibilityUsageGestures.replaceAll('• ', '')).li,
                  Text(context.i18n.accessibilityUsageMonitor.replaceAll('• ', '')).li,
                  Text(context.i18n.accessibilityUsageNoData.replaceAll('• ', '')).li,
                  SizedBox(height: 16),
                  Text(
                    context.i18n.accessibilityDisclaimer,
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  SizedBox(height: 16),
                  Text(
                    context.i18n.mustChooseAllowOrDeny,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          DestructiveButton(
            onPressed: onDeny,
            child: Text(context.i18n.deny),
          ),
          PrimaryButton(
            onPressed: onAccept,
            child: Text(context.i18n.allow),
          ),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}
