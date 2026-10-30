import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
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
