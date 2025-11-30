import 'package:flutter/material.dart' show BackButton;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/utils/core.dart';

class ButtonSimulator extends StatelessWidget {
  const ButtonSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: [BackButton()],
        ),
      ],
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [...ZwiftButtons.values]
            .map(
              (e) => OutlineButton(
                child: Text(e.name),
                onPressed: () {
                  if (core.connection.devices.isNotEmpty) {
                    core.connection.devices.firstOrNull?.handleButtonsClicked([e]);
                    core.connection.devices.firstOrNull?.handleButtonsClicked([]);
                  } else {
                    core.actionHandler.performAction(e);
                    /*final point = Offset(300, 300);
                                await keyPressSimulator.simulateMouseClickDown(point);
                                // slight move to register clicks on some apps, see issue #116
                                await keyPressSimulator.simulateMouseClickUp(point);*/
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }
}
