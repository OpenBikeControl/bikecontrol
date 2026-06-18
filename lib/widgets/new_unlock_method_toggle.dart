import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Toggle that switches between the new split left/right Click V2 controllers
/// (with the unlock handling the right side avoids entirely) and the legacy
/// single [ZwiftClickV2]. Shown in the settings of all three Click V2 device
/// variants. Defaults on.
///
/// Flipping it re-creates the connected Click(s): a plain disconnect drops them
/// from the scan cache so the active scan rediscovers and reconnects them with
/// the representation the new setting now selects.
class NewUnlockMethodToggle extends StatefulWidget {
  const NewUnlockMethodToggle({super.key});

  @override
  State<NewUnlockMethodToggle> createState() => _NewUnlockMethodToggleState();
}

class _NewUnlockMethodToggleState extends State<NewUnlockMethodToggle> {
  late bool _enabled = core.settings.getUseNewUnlockMethod();

  Future<void> _onChanged(bool value) async {
    // Read localised text up front: disconnecting below removes this card from
    // the tree, so `context` may be unmounted by the time we show the toast.
    final reconnectingMessage = context.i18n.unlock_newMethodReconnecting;

    setState(() => _enabled = value);
    await core.settings.setUseNewUnlockMethod(value);

    final clicks = core.connection.bluetoothDevices
        .where((d) => d is ZwiftClickV2 || d is ZwiftClickV2RightSide)
        .toList();
    for (final device in clicks) {
      await core.connection.disconnect(device, forget: false, persistForget: false);
    }
    if (clicks.isNotEmpty) {
      buildToast(title: reconnectingMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(context.i18n.unlock_newMethod).small.semiBold),
            Switch(value: _enabled, onChanged: _onChanged),
          ],
        ),
        Text(context.i18n.unlock_newMethodDescription).xSmall.muted,
      ],
    );
  }
}
