import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<Widget> buildMenuButtons(BuildContext context, VoidCallback? openLogs) {
  return [
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
    Builder(
      builder: (context) {
        return OutlineButton(
          density: ButtonDensity.icon,
          onPressed: () {
            showDropdown(
              context: context,
              builder: (c) => DropdownMenu(
                children: [
                  MenuButton(
                    leading: Icon(Icons.help_outline),
                    child: Text(context.i18n.troubleshootingGuide),
                    onPressed: (c) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
                      );
                    },
                  ),
                  MenuDivider(),
                  MenuLabel(child: Text(context.i18n.getSupport)),
                  MenuButton(
                    leading: Icon(Icons.reddit_outlined),
                    onPressed: (c) {
                      launchUrlString('https://www.reddit.com/r/BikeControl/');
                    },
                    child: Text('Reddit'),
                  ),
                  MenuButton(
                    leading: Icon(Icons.facebook_outlined),
                    onPressed: (c) {
                      launchUrlString('https://www.facebook.com/groups/1892836898778912');
                    },
                    child: Text('Facebook'),
                  ),
                  MenuButton(
                    leading: Icon(RadixIcons.githubLogo),
                    onPressed: (c) {
                      launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
                    },
                    child: Text('GitHub'),
                  ),
                  if (!kIsWeb) ...[
                    MenuButton(
                      leading: Icon(Icons.email_outlined),
                      child: Text('Mail'),
                      onPressed: (c) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Mail Support'),
                              content: Container(
                                constraints: BoxConstraints(maxWidth: 400),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 16,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).mailSupportExplanation,
                                    ),
                                    ...[
                                      OutlineButton(
                                        leading: Icon(Icons.reddit_outlined),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          launchUrlString('https://www.reddit.com/r/BikeControl/');
                                        },
                                        child: const Text('Reddit'),
                                      ),
                                      OutlineButton(
                                        leading: Icon(Icons.facebook_outlined),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          launchUrlString('https://www.facebook.com/groups/1892836898778912');
                                        },
                                        child: const Text('Facebook'),
                                      ),
                                      OutlineButton(
                                        leading: Icon(RadixIcons.githubLogo),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          launchUrlString('https://github.com/jonasbark/swiftcontrol/issues');
                                        },
                                        child: const Text('GitHub'),
                                      ),
                                      SecondaryButton(
                                        leading: Icon(Icons.mail_outlined),
                                        onPressed: () {
                                          Navigator.pop(context);

                                          final isFromStore = (Platform.isAndroid
                                              ? isFromPlayStore == true
                                              : Platform.isIOS);
                                          final suffix = isFromStore ? '' : '-sw';

                                          String email = Uri.encodeComponent('jonas$suffix@bikecontrol.app');
                                          String subject = Uri.encodeComponent(
                                            context.i18n.helpRequested(packageInfoValue?.version ?? ''),
                                          );
                                          String body = Uri.encodeComponent("""
                ${debugText()}""");
                                          Uri mail = Uri.parse("mailto:$email?subject=$subject&body=$body");

                                          launchUrl(mail);
                                        },
                                        child: const Text('Mail'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
          child: Icon(
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
Target: ${core.settings.getLastTarget()?.name ?? '-'}
Trainer App: ${core.settings.getTrainerApp()?.name ?? '-'}
Connected Controllers: ${core.connection.devices.map((e) => e.toString()).join(', ')}
Connected Trainers: ${core.logic.connectedTrainerConnections.map((e) => e.title).join(', ')}
Logs: 
${core.connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}
''';
}

class BKMenuButton extends StatelessWidget {
  final VoidCallback? openLogs;
  const BKMenuButton({super.key, this.openLogs});

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
                Navigator.push(context, MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'CHANGELOG.md')));
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
