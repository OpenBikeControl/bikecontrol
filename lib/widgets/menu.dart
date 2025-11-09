import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../pages/device.dart';

List<Widget> buildMenuButtons() {
  return [
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) ...[
      PopupMenuButton(
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
              child: Text('via Credit Card, Google Pay, Apple Pay and others'),
              onTap: () {
                final currency = NumberFormat.simpleCurrency(locale: kIsWeb ? 'de_DE' : Platform.localeName);
                final link = switch (currency.currencyName) {
                  'USD' => 'https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201',
                  _ => 'https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200',
                };
                launchUrlString(link);
              },
            ),
            if (!kIsWeb && Platform.isAndroid && isFromPlayStore == false)
              PopupMenuItem(
                child: Text('by buying the app from Play Store'),
                onTap: () {
                  launchUrlString('https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol');
                },
              ),
            PopupMenuItem(
              child: Text('via PayPal'),
              onTap: () {
                launchUrlString('https://paypal.me/boni');
              },
            ),
          ];
        },
        icon: Text(
          'Donate ♥',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      ),
      SizedBox(width: 8),
    ],
    PopupMenuButton(
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem(
            child: Text('Instructions'),
            onTap: () {
              final instructions = Platform.isAndroid
                  ? 'INSTRUCTIONS_ANDROID.md'
                  : Platform.isIOS
                  ? 'INSTRUCTIONS_IOS.md'
                  : Platform.isMacOS
                  ? 'INSTRUCTIONS_MACOS.md'
                  : 'INSTRUCTIONS_WINDOWS.md';
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: instructions)),
              );
            },
          ),
          PopupMenuItem(
            child: Text('Troubleshooting Guide'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
              );
            },
          ),
          PopupMenuItem(
            child: Text('Provide Feedback'),
            onTap: () {
              launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
            },
          ),
          if (!kIsWeb)
            PopupMenuItem(
              child: Text('Get Support'),
              onTap: () {
                final isFromStore = (Platform.isAndroid ? isFromPlayStore == true : Platform.isIOS);
                final suffix = isFromStore ? '' : '-sw';

                String email = Uri.encodeComponent('jonas$suffix@swiftcontrol.app');
                String subject = Uri.encodeComponent("Help requested for SwiftControl v${packageInfoValue?.version}");
                String body = Uri.encodeComponent("""
                
                
---
App Version: ${packageInfoValue?.version}${shorebirdPatch?.number != null ? '+${shorebirdPatch!.number}' : ''}
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Target: ${settings.getLastTarget()?.title ?? '-'}
Trainer App: ${settings.getTrainerApp()?.name ?? '-'}
Connected Controllers: ${connection.devices.map((e) => e.toString()).join(', ')}
Logs: 
${connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}

Please don't remove this information, it helps me to assist you better.""");
                Uri mail = Uri.parse("mailto:$email?subject=$subject&body=$body");

                launchUrl(mail);
              },
            ),
        ];
      },
      icon: Icon(Icons.help_outline),
    ),
    SizedBox(width: 8),
    const MenuButton(),
    SizedBox(width: 8),
  ];
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder: (c) => [
        if (kDebugMode) ...[
          PopupMenuItem(
            child: PopupMenuButton(
              child: Text("Simulate buttons"),
              itemBuilder: (_) {
                return ControllerButton.values
                    .map(
                      (e) => PopupMenuItem(
                        child: Text(e.name),
                        onTap: () {
                          Future.delayed(Duration(seconds: 2)).then((_) {
                            connection.signalNotification(
                              ButtonNotification(buttonsClicked: [e]),
                            );
                            connection.devices.firstOrNull?.handleButtonsClicked([e]);
                          });
                        },
                      ),
                    )
                    .toList();
              },
            ),
          ),
          PopupMenuItem(
            child: Text('Continue'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => DevicePage()));
            },
          ),
          PopupMenuItem(
            child: Text('Reset'),
            onTap: () async {
              await settings.reset();
            },
          ),
          PopupMenuItem(child: PopupMenuDivider()),
        ],
        PopupMenuItem(
          child: Text('Changelog'),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'CHANGELOG.md')));
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
