import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/pages/subscription.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../utils/iap/iap_manager.dart';

List<Widget> buildMenuButtons(BuildContext context) {
  final iap = IAPManager.instance;
  return [
    // Pro/Subscription Button
    Builder(
      builder: (context) {
        return Button(
          style: ButtonStyle.primary()
              .withBackgroundColor(color: iap.isProEnabled && false ? BKColor.mainEnd : null)
              .withBorderRadius(
                borderRadius: BorderRadius.circular(16),
              ),
          onPressed: () {
            openDrawer(
              context: context,
              builder: (c) => SubscriptionPage(),
              position: OverlayPosition.end,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, size: 14),
              const SizedBox(width: 4),
              Text('Pro'),
            ],
          ),
        );
      },
    ),

    if (IAPManager.instance.isPurchased.value || IAPManager.instance.isProEnabled) ...[
      Gap(8),
      Builder(
        builder: (context) {
          return IconButton(
            variance: ButtonVariance.menu,
            density: ButtonDensity.iconDense,
            onPressed: () {
              showDropdown(
                context: context,
                builder: (c) => DropdownMenu(
                  children: [
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
            icon: Icon(Icons.favorite_outline),
          );
        },
      ),
    ],
    Gap(4),

    BKMenuButton(),
  ];
}

Future<String> debugText() async {
  final userId = IAPManager.instance.isUsingRevenueCat ? (await Purchases.appUserID) : null;
  final proxies = core.connection.proxyDevices;
  final proxyBlock = proxies.isEmpty
      ? '-'
      : proxies.map(_describeProxyDevice).join('\n  ');
  return '''

---
App Version: ${packageInfoValue?.version}${shorebirdPatch?.number != null ? '+${shorebirdPatch!.number}' : ''}
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Target: ${core.settings.getLastTarget()?.name ?? '-'}
Trainer App: ${core.settings.getTrainerApp()?.name ?? '-'}
Connected Controllers: ${core.connection.devices.map((e) => e.toString()).join(', ')}
Connected Trainers: ${core.logic.connectedTrainerConnections.map((e) => e.title).join(', ')}
Smart Trainers (Proxy):
  $proxyBlock
Status: ${IAPManager.instance.getStatusMessage()}${userId != null ? ' (User ID: $userId)' : ''}
Logs:
${core.connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}
''';
}

/// Compact one-line summary of a [ProxyDevice] for the support / feedback
/// payload. Pulls in the bits that matter for diagnosing a Bridge / proxy
/// issue: connection state, retrofit mode, the active definition class, and
/// any current telemetry.
String _describeProxyDevice(ProxyDevice device) {
  final emulator = device.emulator;
  final state = !device.isConnected
      ? 'disconnected'
      : !emulator.isStarted.value
      ? 'starting'
      : emulator.isConnected.value
      ? 'bridged'
      : 'started';
  final mode = emulator.retrofitMode.value.name;
  final def = emulator.activeDefinition;
  final defKind = def == null ? 'none' : def.runtimeType.toString();

  final parts = <String>[
    device.scanResult.name ?? device.scanResult.deviceId,
    'state=$state',
    'mode=$mode',
    'def=$defKind',
  ];
  if (device.firmwareVersion != null) parts.add('fw=${device.firmwareVersion}');
  if (device.manufacturerName != null) parts.add('mfg=${device.manufacturerName}');

  if (def is FitnessBikeDefinition) {
    parts.add('gear=${def.currentGear.value}/${def.maxGear}');
    parts.add('trainerMode=${def.trainerMode.value.name}');
    final power = def.powerW.value;
    final cadence = def.cadenceRpm.value;
    final speed = def.speedKph.value;
    final hr = def.heartRateBpm.value;
    if (power != null) parts.add('power=${power}W');
    if (cadence != null) parts.add('cadence=${cadence}rpm');
    if (speed != null) parts.add('speed=${speed.toStringAsFixed(1)}km/h');
    if (hr != null) parts.add('hr=${hr}bpm');
  }
  return parts.join(' · ');
}

class BKMenuButton extends StatelessWidget {
  const BKMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      variance: ButtonVariance.menu,
      density: ButtonDensity.iconDense,
      icon: Icon(Icons.more_vert),
      onPressed: () => showDropdown(
        context: context,
        builder: (c) => DropdownMenu(
          children: [
            if (kDebugMode) ...[
              MenuButton(
                child: Text(context.i18n.continueAction),
                onPressed: (c) {
                  //IAPManager.instance.purchaseFullVersion(context);
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
                child: Text('Send Key'),
                onPressed: (c) async {
                  await Future.delayed(Duration(seconds: 2));
                  await keyPressSimulator.simulateKeyDown(
                    PhysicalKeyboardKey.keyK,
                    [],
                    core.settings.getTrainerApp()?.packageName,
                  );
                  await keyPressSimulator.simulateKeyUp(
                    PhysicalKeyboardKey.keyK,
                    [],
                    core.settings.getTrainerApp()?.packageName,
                  );
                },
              ),
              MenuButton(
                child: Text('Disconnect'),
                onPressed: (c) async {
                  core.connection.disconnectAll();
                },
              ),
              MenuButton(
                child: Text('Show Paywall'),
                onPressed: (c) async {
                  openDrawer(
                    context: context,
                    builder: (c) => Paywall(),
                    position: OverlayPosition.bottom,
                  );
                },
              ),
              MenuDivider(),
            ],
            if (kDebugMode) ...[
              MenuButton(
                child: Text('Reset IAP State'),
                onPressed: (c) async {
                  IAPManager.instance.reset(false);
                  core.settings.init();
                },
              ),
              MenuDivider(),
            ],
            MenuButton(
              leading: Icon(Icons.logo_dev_sharp),
              child: Text(context.i18n.logs),
              onPressed: (c) async {
                await context.push(LogViewer());
              },
            ),
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
