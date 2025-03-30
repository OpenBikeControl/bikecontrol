import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<Widget> buildMenuButtons() {
  return [
    TextButton(
      onPressed: () {
        launchUrlString('https://paypal.me/boni');
      },
      child: Text('Donate ♥'),
    ),
    const MenuButton(),
    SizedBox(width: 8),
  ];
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder:
          (c) => [
            if (kDebugMode) ...[
              PopupMenuItem(
                child: Text('Gear up'),
                onTap: () {
                  Future.delayed(Duration(seconds: 2)).then((_) {
                    actionHandler.increaseGear();
                  });
                },
              ),
              PopupMenuItem(
                child: Text('Gear down'),
                onTap: () {
                  Future.delayed(Duration(seconds: 2)).then((_) {
                    actionHandler.decreaseGear();
                  });
                },
              ),
              PopupMenuItem(child: PopupMenuDivider()),
            ],
            PopupMenuItem(
              child: Text('Feedback'),
              onTap: () {
                launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
              },
            ),
            PopupMenuItem(
              child: Text('License'),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
          ],
    );
  }
}
