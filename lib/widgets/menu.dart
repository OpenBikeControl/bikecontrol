import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/profiles/all_profiles.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/pages/subscription.dart';
import 'package:bike_control/services/network_self_test/network_self_test_store.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/iap/iap_manager.dart';
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/main.dart' show recordError, screenshotMode;

List<Widget> buildMenuButtons(BuildContext context) {
  final iap = IAPManager.instance;
  return [
    // Pro/Subscription Button.
    //
    // Not in [screenshotMode]: the marketing renders lay the app bar out
    // narrower than a real window, and this button takes enough of the trailing
    // side that the wordmark wraps mid-word — "BikeContr / ol". Dropping it
    // gives the title its line back, and a Pro upsell is not what the store
    // boards are selling anyway.
    if (!screenshotMode)
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

/// Test seam: stands in for [DebugDiagnostics.gather] inside [debugText], so a
/// test can model a gather that hangs. Null outside tests.
@visibleForTesting
Future<DebugDiagnostics> Function({bool includeDiscovery})? debugDiagnosticsGatherOverride;

Future<String> debugText({bool includeDiscovery = true}) async {
  // Every value here is read defensively. debugText also runs on the
  // startup-failure path (the recovery screen's "won't start" support mail),
  // where the app is only half-initialised: a naive field read throws
  // LateInitializationError (e.g. settings.prefs before init finished) and the
  // whole block used to be dropped. A guard per value degrades one field to '?'
  // instead of losing the entire report, and the two awaited calls get a
  // timeout so a stuck plugin can't hang the report either.
  String guard(String Function() f) {
    try {
      return f();
    } catch (_) {
      return '?';
    }
  }

  String? userId;
  try {
    userId = IAPManager.instance.isUsingRevenueCat
        ? await Purchases.appUserID.timeout(const Duration(seconds: 3))
        : null;
  } catch (_) {
    userId = null;
  }

  final proxyBlock = guard(() {
    final proxies = core.connection.proxyDevices;
    return proxies.isEmpty ? '-' : proxies.map(describeProxyDevice).join('\n  ');
  });

  String diagnostics;
  try {
    final gather = debugDiagnosticsGatherOverride ?? DebugDiagnostics.gather;
    final diag = await gather(includeDiscovery: includeDiscovery).timeout(const Duration(seconds: 6));
    diagnostics = diag.toText();
  } catch (e, s) {
    recordError(e, s, context: 'debugText.diagnostics');
    diagnostics = 'Diagnostics: (unavailable)';
  }
  final networkTest = guard(() => NetworkSelfTestStore.bundleSection());
  return '''

---
App Version: ${guard(() => '${packageInfoValue?.version}${shorebirdPatch?.number != null ? '+${shorebirdPatch!.number}' : ''}')}
Update Track: ${guard(() => IAPManager.instance.isBetaTester ? 'beta' : 'stable')}
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Target: ${guard(() => core.settings.getLastTarget()?.name ?? '-')}
Trainer App: ${guard(() => core.settings.getTrainerApp()?.name ?? '-')}
Connected Controllers: ${guard(() => describeControllers(core.connection.devices))}
Connected Trainers: ${guard(() => core.logic.connectedTrainerConnections.map((e) => e.title).join(', '))}
Smart Trainers:
  $proxyBlock
Status: ${guard(() => IAPManager.instance.getStatusMessage())}${userId != null ? ' (User ID: $userId)' : ''}
$diagnostics
${networkTest.isEmpty ? '' : '$networkTest\n'}Logs:
${guard(() => core.connection.lastLogEntries.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}'))}${guard(() {
    // Verbose DirCon/trainer wire trace, in its own section so it never
    // crowds out the high-level Logs above.
    final trace = core.connection.lastTraceEntries;
    return trace.isEmpty
        ? ''
        : '\n\nWire trace:\n${trace.reversed.joinToString(separator: '\n', transform: (e) => '${e.date.toString().split('.').first} - ${e.entry}')}';
  })}
''';
}

/// Compact summary of a [ProxyDevice] for the support / feedback payload.
/// First line lists the bits that matter for diagnosing a Bridge / proxy
/// issue (state, retrofit mode, active definition class, firmware,
/// manufacturer). When the emulator has discovered non-standard BLE
/// services on the trainer, the same "Services & characteristics:" block
/// the chat freetext uses is appended on subsequent lines.
@visibleForTesting
String describeProxyDevice(ProxyDevice device) {
  final emulator = device.emulator;
  final state = !device.isConnected
      ? 'disconnected'
      : !emulator.isStarted.value
      ? 'starting'
      : emulator.isConnected.value
      ? 'bridged'
      : 'started';
  final mode = device.retrofitMode.value.name;
  // Not emulator.fitnessBike: [emulator] is contextual (proxy vs. the shared
  // ftmsEmulator) and swaps with retrofit mode, while [ProxyDevice.fitnessBike]
  // always tracks the current FBD regardless — see the identical reasoning at
  // navigation.dart's `_tryAutoShowOverlayFor`. It's also what makes the
  // `debugAttachFitnessBike` test hook (and the self-test harness) reach this.
  final def = device.fitnessBike;
  final defKind = def == null ? 'none' : def.runtimeType.toString();
  // Hoisted out of the `def != null` block below so its step log can be printed
  // as its own block after the services block, alongside the inline
  // `selfTest=` summary field still added inside it.
  SelfTestResult? selfTest;

  final parts = <String>[
    device.scanResult.name ?? device.scanResult.deviceId,
    // The *upstream* link to the real trainer, as opposed to `mode` below
    // (the downstream retrofit mode BikeControl emulates towards the trainer
    // app). One physical trainer is often discovered twice — over BLE and over
    // mDNS/DirCon — and this is what tells the two entries apart in a bundle.
    'upstream=${device.isWifiUpstream ? 'wifi' : 'ble'}',
    'mode=$mode',
    'state=$state',
    'def=$defKind',
  ];
  if (device.firmwareVersion != null) parts.add('fw=${device.firmwareVersion}');
  if (device.manufacturerName != null) parts.add('mfg=${device.manufacturerName}');
  if (def != null) {
    parts.add(
      'gear=${formatGearReadout(currentGear: def.currentGear.value, maxGear: def.maxGear, frontShiftEnabled: def.frontShiftEnabled, largeRing: def.frontRing.value == FrontRing.large)}',
    );
    parts.add('trainerMode=${def.trainerMode.value.name}');
    // `(manual)` separates a rider-forced delivery from an auto-picked one —
    // otherwise the two read identically, and "did you change the protocol?"
    // is support's first question on any "trainer ignores BikeControl" report.
    parts.add('proto=${def.controlProtocol.name}${def.controlProtocolOverride != null ? '(manual)' : ''}');
    // Only worth a field when there was actually something to choose between;
    // on a plain FTMS trainer it would be noise in every bundle.
    if (def.supportedControlProtocols.length > 1) {
      parts.add('protoAvail=${def.supportedControlProtocols.map((p) => p.name).join('+')}');
    }
    // `saved→effective` when the trainer reports no cadence: the cadence-driven
    // modes skip every write there, so BikeControl drives trackResistance
    // instead. Printing only the saved mode hides what the trainer was actually
    // given — the one thing a "gears change, nothing happens" bundle is read
    // for.
    final savedVsMode = def.virtualShiftingMode.value;
    final drivenVsMode = def.effectiveVirtualShiftingMode;
    parts.add(
      'vsMode=${savedVsMode.name}${drivenVsMode == savedVsMode ? '' : '→${drivenVsMode.name}'}',
    );
    parts.add('ftms=${def.ftmsCapabilitySummary}');
    // Live telemetry BikeControl is reading from the trainer: cad shows raw /
    // filtered rpm. The whole VS resistance calc is cadence-driven, so a "no
    // resistance" bundle with cad:0 (while pedalling) means we aren't getting
    // cadence — non-zero means the trainer is understood and the cause is
    // downstream. spd in km/h.
    parts.add(
      'read=cad:${def.cadenceRpm.value ?? '-'}/${def.filteredCadence} '
      'pwr:${def.powerW.value ?? '-'} spd:${def.speedKph.value?.toStringAsFixed(1) ?? '-'}',
    );
    // Only for trainers that actually speak Zwift Sync; 'n/a' everywhere else
    // would be noise. `timeout` here is what separates "the trainer ignores
    // our commands" from "the trainer never opened its command interface" —
    // lastCtl=ok reads identically in both cases.
    final handshake = def.zwiftHandshakeSummary;
    if (handshake != 'n/a') parts.add('zwiftHandshake=$handshake');
    // Whether the trainer acknowledges our native gear commands. `ignored→ftms`
    // is the one line that explains a proto=ftms on a trainer that advertises
    // the native path; `missed·N` shows a verdict building up.
    final gearAck = def.gearEchoSummary;
    if (gearAck != 'n/a') parts.add('zwiftGearAck=$gearAck');
    // The trainer refused to start grade simulation and virtual shifting was
    // switched to power — the line that explains vsMode=targetPower on a
    // bundle whose rider picked Track Resistance.
    if (def.trackResistanceRefused.value) parts.add('simGrade=refused→power');
    final ctl = def.lastControlWrite;
    if (ctl != null) {
      final age = DateTime.now().difference(ctl.at).inSeconds;
      parts.add('lastCtl=${ctl.ok ? 'ok' : 'fail'}·${age}s');
    }
    selfTest = SelfTestResult.tryParse(core.settings.getSelfTestResultJson(device.trainerKey));
    if (selfTest != null) parts.add('selfTest=${selfTest.toBundleString()}');
  }

  final blocks = <String>[parts.join(' · ')];
  final services = buildProxyServicesFreetext(device);
  // Indent the services block so it visibly belongs to its proxy entry.
  if (services != null) blocks.add(services.split('\n').map((l) => '    $l').join('\n'));
  // The one-line verdict is already the `selfTest=` field above; this is the
  // full step-by-step trace, indented under the proxy entry like the services
  // block so a bundle keeps the per-gear plateau numbers the volatile app log
  // has long since dropped by the time a rider sends it.
  if (selfTest != null && selfTest.stepLog.isNotEmpty) {
    final log = selfTest.stepLog.map((l) => '      $l').join('\n');
    blocks.add('    Self-test log:\n$log');
  }
  return blocks.join('\n');
}

/// Compact `Connected Controllers:` rendering for the support bundle — plain
/// `toString()` per device, plus `(fw <version>)` when a firmware read
/// succeeded.
///
/// Takes [BaseDevice], not [BluetoothDevice]: `core.connection.devices` also
/// holds gamepad / HID / gyroscope-steering controllers, which carry no
/// firmware field, and dropping them from this line would be a real support
/// regression, not just a formatting change.
@visibleForTesting
String describeControllers(Iterable<BaseDevice> devices) => devices.map((e) {
  final fw = e is BluetoothDevice ? e.firmwareVersion : null;
  return fw != null ? '$e (fw $fw)' : e.toString();
}).join(', ');

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
                subMenu: [
                  for (final profile in allEmulationProfiles)
                    MenuButton(
                      onPressed: (c) {
                        core.emulation.start(profile);
                        unawaited(core.connection.performScanning());
                      },
                      child: Text(profile.name),
                    ),
                ],
                child: const Text('Emulate device'),
              ),
              MenuButton(
                child: Text(context.i18n.reset),
                onPressed: (c) async {
                  await core.settings.reset();
                },
              ),
              // Debug-only: the real prompt needs six successful sessions, a
              // three-day-old install and no ride in progress, so there is no
              // practical way to see it on demand. Calls the flow directly and
              // therefore bypasses FeedbackPromptTrigger's once-per-launch
              // guard as well — reopen it as often as you like.
              MenuButton(
                child: const Text('Show feedback prompt'),
                onPressed: (c) => showFeedbackPromptFlow(context, service: core.feedbackPromptService),
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
              leading: Icon(Icons.tips_and_updates_outlined),
              child: Text(context.i18n.onboardingMenuEntry),
              onPressed: (c) async {
                await Navigator.of(context).push(
                  MaterialPageRoute(fullscreenDialog: true, builder: (_) => OnboardingPage()),
                );
              },
            ),
            MenuButton(
              leading: Icon(Icons.logo_dev_sharp),
              child: Text(context.i18n.logs),
              onPressed: (c) async {
                await context.push(LogViewer());
              },
            ),
            if (!kIsWeb)
              MenuButton(
                leading: Icon(Icons.wifi_find_outlined),
                child: Text(context.i18n.networkTroubleshootingTitle),
                onPressed: (c) async {
                  await context.push(const NetworkTroubleshootingPage());
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
