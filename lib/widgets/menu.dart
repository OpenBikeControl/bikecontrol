import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder:
          (c) => [
            PopupMenuItem(
              child: Text('Feedback'),
              onTap: () {
                launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
              },
            ),
            PopupMenuItem(
              child: Text('Donate 🫶'),
              onTap: () {
                launchUrlString('https://paypal.me/boni');
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
