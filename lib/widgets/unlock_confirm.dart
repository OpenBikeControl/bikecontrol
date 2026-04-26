import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter/scheduler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class UnlockConfirm extends StatefulWidget {
  final ZwiftClickV2 device;
  const UnlockConfirm({super.key, required this.device});

  @override
  State<UnlockConfirm> createState() => _UnlockConfirmState();
}

class _UnlockConfirmState extends State<UnlockConfirm> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 60;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final waitUntil = widget.device.initializationTime!.add(Duration(minutes: 1));
      final secondsUntil = waitUntil.difference(DateTime.now()).inSeconds;

      if (mounted) {
        _secondsRemaining = secondsUntil;
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CircularProgressIndicator(value: 1 - (_secondsRemaining / 60)),
        ),
        if (_secondsRemaining > 0)
          Text(AppLocalizations.of(context).unlockAfterMinuteCheck).xSmall
        else
          Text(AppLocalizations.of(context).unlockConfirmByButton).xSmall,
      ],
    );
  }
}
