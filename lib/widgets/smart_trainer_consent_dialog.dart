import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _smartTrainerLearnMoreUrl =
    'https://bikecontrol.app/blog/bikecontrol-5-4-smart-trainers-virtual-shifting';

/// One-time explainer shown when the user first taps a smart trainer:
/// BikeControl is about to take over Virtual Shifting and the trainer app
/// will need to connect to the BikeControl virtual trainer instead.
/// Returns true only if the user clicks Continue.
Future<bool> showSmartTrainerConsentDialog(
  BuildContext context, {
  required String trainerName,
  required String appName,
}) async {
  final l10n = AppLocalizations.of(context);
  final disconnectLabel = l10n.disconnectAndForgetForThisSession;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => Container(
      constraints: const BoxConstraints(maxWidth: 480),
      child: AlertDialog(
        title: Text(l10n.smartTrainerConsentTitle(trainerName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.smartTrainerConsentMessage(trainerName, appName, disconnectLabel)),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Button.text(
                onPressed: () => launchUrlString(_smartTrainerLearnMoreUrl),
                child: Text(l10n.moreInformation),
              ),
            ),
          ],
        ),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(context.i18n.cancel),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(context.i18n.continueAction),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}
