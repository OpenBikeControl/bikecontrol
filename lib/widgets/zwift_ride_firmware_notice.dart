import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Opens the in-app support chat pre-filled for a Zwift controller whose
/// firmware is past the last supported version. Deliberately neutral: it routes
/// the rider to a human and says nothing about firmware tooling or downgrading.
void openZwiftRideFirmwareSupport(BuildContext context, ZwiftDevice device) {
  final firmware = device.firmwareVersion ?? '';
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SupportChatPage(
        initialText: context.i18n.zwiftRideFirmwareSupportPrefill(firmware),
        initialIntake: IntakeAnswers(
          category: IntakeCategory.controller,
          subcategory: 'device',
          subcategoryValue: controllerOptionIdFor(device) ?? 'zwift_ride',
        ),
        telemetryBuilder: () async =>
            TelemetrySnapshot.general(freetext: 'Zwift Ride firmware: ${firmware.isEmpty ? 'unknown' : firmware}'),
      ),
    ),
  );
}

/// One-time dialog shown when an affected Ride is first detected.
Future<void> showZwiftRideFirmwareDialog(BuildContext context, ZwiftRide device) async {
  await showDialog<void>(
    context: context,
    builder: (c) => Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(c.i18n.zwiftRideFirmwareNoticeTitle)),
          ],
        ),
        content: Text(c.i18n.zwiftRideFirmwareNoticeBody(device.firmwareVersion ?? '')),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(c.i18n.zwiftRideFirmwareLater),
          ),
          PrimaryButton(
            onPressed: () {
              Navigator.of(c).pop();
              openZwiftRideFirmwareSupport(context, device);
            },
            child: Text(c.i18n.onboardingHelpSupport),
          ),
        ],
      ),
    ),
  );
}

/// Persistent advisory shown on the Zwift Ride's controller card when its
/// firmware is past the last supported version. Mirrors
/// [VirtualShiftingProNotice]; routes to support without mentioning any tooling.
class ZwiftRideFirmwareNotice extends StatelessWidget {
  final ZwiftRide device;

  const ZwiftRideFirmwareNotice({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.i18n;
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
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              Expanded(
                child: Text(
                  l10n.zwiftRideFirmwareNoticeBody(device.firmwareVersion ?? ''),
                  style: TextStyle(fontSize: 12, color: cs.foreground),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Button.primary(
              onPressed: () => openZwiftRideFirmwareSupport(context, device),
              leading: const Icon(Icons.support_agent, size: 14),
              child: Text(l10n.onboardingHelpSupport),
            ),
          ),
        ],
      ),
    );
  }
}
