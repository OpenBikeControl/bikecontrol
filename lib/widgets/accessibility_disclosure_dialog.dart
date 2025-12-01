import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/gen/app_localizations.dart';

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
        title: Text(AppLocalizations.current.accessibilityServicePermissionRequired),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.current.accessibilityServiceExplanation,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(AppLocalizations.current.whyPermissionNeeded),
              SizedBox(height: 8),
              Text(AppLocalizations.current.accessibilityReasonTouch),
              Text(AppLocalizations.current.accessibilityReasonWindow),
              Text(AppLocalizations.current.accessibilityReasonControl),
              SizedBox(height: 16),
              Text(
                AppLocalizations.current.howBikeControlUsesPermission,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(AppLocalizations.current.accessibilityUsageGestures),
              Text(AppLocalizations.current.accessibilityUsageMonitor),
              Text(AppLocalizations.current.accessibilityUsageNoData),
              SizedBox(height: 16),
              Text(
                AppLocalizations.current.accessibilityDisclaimer,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.current.mustChooseAllowOrDeny,
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          DestructiveButton(
            onPressed: onDeny,
            child: Text(AppLocalizations.current.deny),
          ),
          PrimaryButton(
            onPressed: onAccept,
            child: Text(AppLocalizations.current.allow),
          ),
        ],
      ),
    );
  }
}
