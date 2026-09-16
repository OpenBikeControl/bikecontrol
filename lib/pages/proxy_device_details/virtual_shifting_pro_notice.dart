import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/register_this_device.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Informational block shown above the Virtual Shifting Settings when the
/// user isn't Pro on this device. Explains the daily limit and offers the
/// action that actually lifts it: Go Pro — or, when the account already has
/// Pro and only this device is missing, registering the device. Telling that
/// rider to "Go Pro" sent them back to the paywall they had already paid at.
class VirtualShiftingProNotice extends StatefulWidget {
  final String trainerAppName;
  final Duration remainingToday;

  const VirtualShiftingProNotice({
    super.key,
    required this.trainerAppName,
    required this.remainingToday,
  });

  @override
  State<VirtualShiftingProNotice> createState() => _VirtualShiftingProNoticeState();
}

class _VirtualShiftingProNoticeState extends State<VirtualShiftingProNotice> {
  final IAPManager _iap = IAPManager.instance;

  /// The parent only mounts this while Pro is off for this device and does
  /// not watch the IAP state itself; following the notifiers here lets a
  /// registration from the button below take the notice away on the spot.
  late final Listenable _iapState = Listenable.merge([_iap.entitlements, _iap.isPurchased, _iap.isLocalPro]);

  int get _remainingMinutesCeil {
    final secs = widget.remainingToday.inSeconds;
    if (secs <= 0) return 0;
    return (secs / 60).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _iapState,
      builder: (context, _) {
        if (_iap.isProEnabledForCurrentDevice) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context);
        final unregistered = _iap.isProButDeviceUnregistered;

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
                      unregistered ? l10n.proUnregisteredBody : l10n.virtualShiftingProNote(widget.trainerAppName),
                      style: TextStyle(fontSize: 12, color: cs.foreground),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  l10n.bridgeMinutesRemainingToday(_remainingMinutesCeil),
                  style: TextStyle(fontSize: 11, color: cs.mutedForeground, fontWeight: FontWeight.w500),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: unregistered
                    ? const RegisterThisDeviceButton()
                    : Button.primary(
                        onPressed: () => showGoProDialog(context),
                        leading: const Icon(Icons.workspace_premium, size: 14),
                        child: Text(l10n.goPro),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
