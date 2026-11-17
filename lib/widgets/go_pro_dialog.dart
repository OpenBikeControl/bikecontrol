import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Shows a dialog prompting the user to upgrade to Pro.
///
/// [featureName] names the thing the rider just reached for. Pass it wherever
/// the entry point is an icon or a toggle: "Pro Feature" alone tells them the
/// price of something they never found out the name of.
///
/// [message] replaces the generic "only with Pro" body, for when there is
/// more to say than that (e.g. today's virtual shifting trial is used up).
///
/// [guide] adds a link beside Go Pro (opens [url] in the browser), for when
/// there is a way forward without Pro.
///
/// Returns true if the user initiated a purchase, false otherwise.
Future<bool> showGoProDialog(
  BuildContext context, {
  String? featureName,
  String? message,
  ({String label, String url})? guide,
}) async {
  final iapManager = IAPManager.instance;

  final result = await showDialog<bool>(
    context: context,
    builder: (c) => Container(
      constraints: BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.crown, color: BkStatusColors.of(c).warning),
            const SizedBox(width: 8),
            Expanded(child: Text(featureName ?? AppLocalizations.of(c).proFeature)),
          ],
        ),
        content: Text(message ?? AppLocalizations.of(c).thisFeatureIsOnlyAvailableWithPro),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(c.i18n.cancel),
          ),
          if (guide != null)
            Button.outline(
              key: const ValueKey('go-pro-guide'),
              onPressed: () => launchUrlString(guide.url, mode: LaunchMode.externalApplication),
              trailing: const Icon(LucideIcons.arrowUpRight, size: 16),
              child: Text(guide.label),
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
