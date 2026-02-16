import 'dart:io';

import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/pages/login.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../utils/iap/iap_manager.dart';

List<Widget> buildMenuButtons(BuildContext context, BCPage currentPage, VoidCallback? openLogs) {
  return [
    if (IAPManager.instance.isPurchased.value)
      Builder(
        builder: (context) {
          return OutlineButton(
            density: ButtonDensity.icon,
            onPressed: () {
              showDropdown(
                context: context,
                builder: (c) => DropdownMenu(
                  children: [
                    if ((!Platform.isIOS && !Platform.isMacOS)) ...[
                      MenuLabel(child: Text(context.i18n.showDonation)),
                      MenuButton(
                        child: Text(context.i18n.donateViaCreditCard),
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
                          child: Text(context.i18n.donateByBuyingFromPlayStore),
                          onPressed: (c) {
                            launchUrlString('https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol');
                          },
                        ),
                      MenuButton(
                        child: Text(context.i18n.donateViaPaypal),
                        onPressed: (c) {
                          launchUrlString('https://paypal.me/boni');
                        },
                      ),
                    ],
                    MenuButton(
                      leading: Icon(Icons.star_rate),
                      child: Text(context.i18n.leaveAReview),
                      onPressed: (c) async {
                        final InAppReview inAppReview = InAppReview.instance;

                        if (await inAppReview.isAvailable()) {
                          inAppReview.requestReview();
                        } else {
                          inAppReview.openStoreListing(appStoreId: 'id6753721284', microsoftStoreId: '9NP42GS03Z26');
                        }
                      },
                    ),
                  ],
                ),
              );
            },
            child: Icon(
              Icons.favorite,
              color: Colors.red,
              size: 18,
            ),
          );
        },
      ),
    Gap(4),

    BKMenuButton(openLogs: openLogs, currentPage: currentPage),
  ];
}

Future<String> debugText() async {
  final userId = IAPManager.instance.isUsingRevenueCat ? (await Purchases.appUserID) : null;
  return '''
                
---
App Version: ${packageInfoValue?.version}${shorebirdPatch?.number != null ? '+${shorebirdPatch!.number}' : ''}
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Target: ${core.settings.getLastTarget()?.name ?? '-'}
Trainer App: ${core.settings.getTrainerApp()?.name ?? '-'}
Connected Controllers: ${core.connection.devices.map((e) => e.toString()).join(', ')}
Connected Trainers: ${core.logic.connectedTrainerConnections.map((e) => e.title).join(', ')}
Status: ${IAPManager.instance.isPurchased.value ? 'Full Version' : 'Test Version'}${userId != null ? ' (User ID: $userId)' : ''}
Logs: 
${core.connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}
''';
}

class BKMenuButton extends StatelessWidget {
  final VoidCallback? openLogs;
  final BCPage currentPage;
  const BKMenuButton({super.key, this.openLogs, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      density: ButtonDensity.icon,
      child: Icon(Icons.more_vert, size: 18),
      onPressed: () => showDropdown(
        context: context,
        builder: (c) => DropdownMenu(
          children: [
            if (kDebugMode) ...[
              MenuButton(
                child: Text(context.i18n.continueAction),
                onPressed: (c) {
                  IAPManager.instance.purchaseFullVersion(context);
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
                child: Text(context.i18n.reset),
                onPressed: (c) async {
                  await core.settings.reset();
                },
              ),
              MenuButton(
                child: Text('Disconnect'),
                onPressed: (c) async {
                  core.connection.disconnectAll();
                },
              ),
              MenuButton(
                child: Text('Login'),
                onPressed: (c) async {
                  openDrawer(
                    context: context,
                    builder: (c) => LoginPage(),
                    position: OverlayPosition.bottom,
                  );
                },
              ),
              MenuDivider(),
            ],
            if (currentPage == BCPage.logs) ...[
              MenuButton(
                child: Text('Reset IAP State'),
                onPressed: (c) async {
                  IAPManager.instance.reset(false);
                  core.settings.init();
                },
              ),
              MenuDivider(),
            ],
            if (openLogs != null)
              MenuButton(
                leading: Icon(Icons.article_outlined),
                child: Text(context.i18n.logs),
                onPressed: (c) {
                  openLogs!();
                },
              ),
            MenuButton(
              leading: Icon(Icons.update_outlined),
              child: Text(context.i18n.changelog),
              onPressed: (c) {
                openDrawer(
                  context: context,
                  position: OverlayPosition.bottom,
                  builder: (c) => MarkdownPage(assetPath: 'CHANGELOG.md'),
                );
              },
            ),
            MenuButton(
              leading: Icon(Icons.policy_outlined),
              child: Text(context.i18n.license),
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
