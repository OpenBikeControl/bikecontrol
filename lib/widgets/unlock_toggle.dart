import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:prop/devices/click_logic.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class UnlockToggle extends StatefulWidget {
  final ZwiftClickV2LeftSide device;
  final List<Widget> children;
  const UnlockToggle({super.key, required this.device, required this.children});

  @override
  State<UnlockToggle> createState() => _UnlockToggleState();
}

class _UnlockToggleState extends State<UnlockToggle> {
  bool _unlockWithZwift = false;

  @override
  void initState() {
    _unlockWithZwift = core.settings.getUnlockWithZwift();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(context.i18n.unlock_mode).small.semiBold,
        Select<bool>(
          value: _unlockWithZwift,
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                SelectItemButton(
                  value: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.i18n.unlock_modeRestart).bold,
                      Text(context.i18n.unlock_modeRestartDescription).xSmall.muted,
                    ],
                  ),
                ),
                SelectItemButton(
                  value: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.i18n.unlock_modeZwift).bold,
                      Text(context.i18n.unlock_modeZwiftDescription).xSmall.muted,
                    ],
                  ),
                ),
              ],
            ),
          ).call,
          itemBuilder: (context, value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value ? context.i18n.unlock_modeZwift : context.i18n.unlock_modeRestart),
              Text(
                value ? context.i18n.unlock_modeZwiftDescription : context.i18n.unlock_modeRestartDescription,
              ).xSmall.normal.muted,
            ],
          ),
          onChanged: (unlockWithZwift) async {
            if (unlockWithZwift == null) return;
            setState(() {
              _unlockWithZwift = unlockWithZwift;
            });
            await core.settings.setUnlockWithZwift(unlockWithZwift);
            if (unlockWithZwift) {
              ClickLogic.resetTimer();
            } else {
              ClickLogic.setupHandshake(widget.device.services!, widget.device.device.deviceId, isRight: false);
            }
          },
        ),

        if (_unlockWithZwift) ...widget.children,
      ],
    );
  }
}
