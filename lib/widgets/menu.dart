import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<Widget> buildMenuButtons(BuildContext context, VoidCallback? openLogs) {
  return [
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) ...[
      Builder(
        builder: (context) {
          return IconButton(
            variance: ButtonVariance.outline,
            onPressed: () {
              showDropdown(
                context: context,
                builder: (c) => DropdownMenu(
                  children: [
                    MenuLabel(child: Text('Show your appreciation by donating')),
                    MenuButton(
                      child: Text('via Credit Card, Google Pay, Apple Pay and others'),
                      onPressed: (c) {
                        final currency = NumberFormat.simpleCurrency(locale: kIsWeb ? 'de_DE' : Platform.localeName);
                        final link = switch (currency.currencyName) {
                          'USD' => 'https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201',
                          _ => 'https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200',
                        };
                        launchUrlString(link);
                      },
                    ),
                    if (!kIsWeb && Platform.isAndroid && isFromPlayStore == false)
                      MenuButton(
                        child: Text('by buying the app from Play Store'),
                        onPressed: (c) {
                          launchUrlString('https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol');
                        },
                      ),
                    MenuButton(
                      child: Text('via PayPal'),
                      onPressed: (c) {
                        launchUrlString('https://paypal.me/boni');
                      },
                    ),
                  ],
                ),
              );
            },
            icon: Text(
              '♥',
              style: TextStyle(color: Colors.red),
            ).bold,
          );
        },
      ),
      Gap(4),
    ],
    Builder(
      builder: (context) {
        return IconButton(
          variance: ButtonVariance.outline,
          onPressed: () {
            showDropdown(
              context: context,
              builder: (c) => DropdownMenu(
                children: [
                  MenuButton(
                    child: Text('Instructions'),
                    onPressed: (c) {
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
                  MenuButton(
                    child: Text('Troubleshooting Guide'),
                    onPressed: (c) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
                      );
                    },
                  ),
                  MenuButton(
                    child: Text('Provide Feedback'),
                    onPressed: (c) {
                      launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
                    },
                  ),
                  MenuDivider(),
                  if (!kIsWeb)
                    MenuButton(
                      child: Text('Get Support'),
                      onPressed: (c) {
                        final isFromStore = (Platform.isAndroid ? isFromPlayStore == true : Platform.isIOS);
                        final suffix = isFromStore ? '' : '-sw';

                        String email = Uri.encodeComponent('jonas$suffix@bikecontrol.app');
                        String subject = Uri.encodeComponent(
                          "Help requested for BikeControl v${packageInfoValue?.version}",
                        );
                        String body = Uri.encodeComponent("""
                ${debugText()}

Please also attach the file ${File('${Directory.current.path}/app.logs').path}, if it exists.
Please don't remove this information, it helps me to assist you better.""");
                        Uri mail = Uri.parse("mailto:$email?subject=$subject&body=$body");

                        launchUrl(mail);
                      },
                    ),
                ],
              ),
            );
          },
          icon: Icon(
            Icons.help_outline,
            size: 18,
          ),
        );
      },
    ),
    Gap(4),
    BKMenuButton(openLogs: openLogs),
  ];
}

String debugText() {
  return '''
                
---
App Version: ${packageInfoValue?.version}${shorebirdPatch?.number != null ? '+${shorebirdPatch!.number}' : ''}
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Target: ${core.settings.getLastTarget()?.title ?? '-'}
Trainer App: ${core.settings.getTrainerApp()?.name ?? '-'}
Connected Controllers: ${core.connection.devices.map((e) => e.toString()).join(', ')}
Logs: 
${core.connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}
''';
}

class BKMenuButton extends StatelessWidget {
  final VoidCallback? openLogs;
  const BKMenuButton({super.key, this.openLogs});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      variance: ButtonVariance.outline,
      icon: Icon(Icons.more_vert, size: 18),
      onPressed: () => showDropdown(
        context: context,
        builder: (c) => DropdownMenu(
          children: [
            if (kDebugMode) ...[
              MenuButton(
                subMenu: ControllerButton.values
                    .map(
                      (e) => MenuButton(
                        child: Text(e.name),
                        onPressed: (c) {
                          Future.delayed(Duration(seconds: 2)).then((_) async {
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
                          });
                        },
                      ),
                    )
                    .toList(),
                child: Text('Simulate buttons'),
              ),
              MenuButton(
                child: Text('Continue'),
                onPressed: (c) {
                  core.connection.addDevices([
                    ZwiftClickV2(
                        BleDevice(
                          name: 'Controller',
                          deviceId: '00:11:22:33:44:55',
                        ),
                      )
                      ..firmwareVersion = '1.2.0'
                      ..rssi = -51
                      ..batteryLevel = 81,
                  ]);
                },
              ),
              MenuButton(
                child: Text('Reset'),
                onPressed: (c) async {
                  await core.settings.reset();
                },
              ),
              MenuDivider(),
            ],
            if (openLogs != null)
              MenuButton(
                child: Text('Logs'),
                onPressed: (c) {
                  openLogs!();
                },
              ),
            MenuButton(
              child: Text('Changelog'),
              onPressed: (c) {
                Navigator.push(context, MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'CHANGELOG.md')));
              },
            ),
            MenuButton(
              child: Text('License'),
              onPressed: (c) {
                showLicensePage(context: context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
