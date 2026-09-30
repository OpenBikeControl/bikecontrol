// Task 9: the personalized "Your setup" section. Pins: the network
// troubleshooting row only appears while a network trainer connection is
// started/connected; the Zwift Click V2 setup-options row only appears while
// a Click V2 side (left or right) is among the known devices; and an empty
// setup shows a muted nudge toward onboarding instead of an empty card. Both
// rows push their target page via `context.push`.
//
// Content-round addition: three explainer rows opening a `HelpAnswerSheet`
// (help_answer_sheet.dart) — "the gear doesn't move" while a trainer app is
// configured, and "keeps disconnecting" / "isn't found" while any controller
// is known. Pins: visibility conditions, the overlay row's deep link (the
// Overlay page in a virtual shifting session, else the trainer's page where
// that session starts) when a ProxyDevice is known (and its link-only fallback when none is), and the exact blog URLs
// wired into the two link actions.
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:bike_control/pages/help_center/widgets/your_setup_section.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _networkRowKey = ValueKey('help-network-troubleshoot');
const _clickV2RowKey = ValueKey('help-clickv2-onboarding');
const _gearOverlayRowKey = ValueKey('help-gear-overlay');
const _controllerDisconnectingRowKey = ValueKey('help-controller-disconnecting');
const _controllerNotFoundRowKey = ValueKey('help-controller-not-found');
const _setupGuideRowKey = ValueKey('help-run-setup-guide');
const _overlayActionKey = ValueKey('help-check-overlay-settings');
const _networkTestActionKey = ValueKey('help-check-network-test');
const _searchAgainActionKey = ValueKey('help-answer-action-search-again');
const _contactSupportActionKey = ValueKey('help-answer-action-contact-support');
const _vsBlogActionKey = ValueKey('help-answer-action-vs-blog');
const _clickV2RestartActionKey = ValueKey('help-answer-action-clickv2-restart-blog');

/// Records every URL passed to `launchUrlString` instead of hitting a real
/// platform channel, so link actions are assertable (mirrors
/// help_center_sections_test.dart's `_FakeUrlLauncher`).
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

class _FakeConnection extends TrainerConnection {
  _FakeConnection({required super.type}) : super(title: () => 'Fake connection', supportedActions: const []);

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async =>
      NotHandled('', button: null);

  @override
  Widget getTile({bool small = false}) => const SizedBox.shrink();
}

Future<void> _pump(
  WidgetTester tester, {
  List<BaseDevice>? devices,
  List<TrainerConnection>? connections,
  VoidCallback? onSearchAgain,
  void Function(String? controllerId)? onContactSupport,
}) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: YourSetupSection(
          devicesOverride: devices,
          connectionsOverride: connections,
          onSearchAgain: onSearchAgain,
          onContactSupport: onContactSupport,
        ),
      ),
    ),
  );
}

/// Taps [rowKey] and lets the sheet's entrance animation run out, so its
/// content is stable for further finds/taps (mirrors the drawer-open pattern
/// in paywall_open_context_test.dart — shadcn's overlay stack, same as
/// `openDrawer`).
Future<void> _openSheet(WidgetTester tester, Key rowKey) async {
  await tester.tap(find.byKey(rowKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Scrolls [key] into view before tapping it — the sheet's body text is long
/// enough that its action rows can sit below the test viewport's fixed
/// 800x600 size inside the sheet's own `SingleChildScrollView`.
Future<void> _tapAction(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  group('network troubleshooting row', () {
    testWidgets('shown when a network connection is started', (tester) async {
      final connection = _FakeConnection(type: ConnectionMethodType.network)..isStarted.value = true;

      await _pump(tester, devices: const [], connections: [connection]);
      await tester.pump();

      expect(find.byKey(_networkRowKey), findsOneWidget);
    });

    testWidgets('shown when a network connection is connected', (tester) async {
      final connection = _FakeConnection(type: ConnectionMethodType.network)..isConnected.value = true;

      await _pump(tester, devices: const [], connections: [connection]);
      await tester.pump();

      expect(find.byKey(_networkRowKey), findsOneWidget);
    });

    testWidgets('absent without any started/connected network connection', (tester) async {
      final idleNetwork = _FakeConnection(type: ConnectionMethodType.network);
      final startedBluetooth = _FakeConnection(type: ConnectionMethodType.bluetooth)..isStarted.value = true;

      await _pump(tester, devices: const [], connections: [idleNetwork, startedBluetooth]);
      await tester.pump();

      expect(find.byKey(_networkRowKey), findsNothing);
    });

    testWidgets('tapping it pushes NetworkTroubleshootingPage', (tester) async {
      final connection = _FakeConnection(type: ConnectionMethodType.network)..isStarted.value = true;

      await _pump(tester, devices: const [], connections: [connection]);
      await tester.pump();

      // Not pumpAndSettle: NetworkTroubleshootingPage kicks off a self-test
      // engine with its own timers/polling, which never settles.
      await tester.tap(find.byKey(_networkRowKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(NetworkTroubleshootingPage), findsOneWidget);
    });
  });

  group('Zwift Click V2 row', () {
    testWidgets('shown when a Click V2 right side is a known device', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();

      expect(find.byKey(_clickV2RowKey), findsOneWidget);
    });

    testWidgets('shown when a unified Click V2 is a known device', (tester) async {
      final unified = ZwiftClickV2(BleDevice(deviceId: 'l1', name: 'Zwift Click'));

      await _pump(tester, devices: [unified], connections: const []);
      await tester.pump();

      expect(find.byKey(_clickV2RowKey), findsOneWidget);
    });

    testWidgets('absent without any Click V2 device', (tester) async {
      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();

      expect(find.byKey(_clickV2RowKey), findsNothing);
    });

    testWidgets('tapping it pushes ClickV2OnboardingPage', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();

      // Not pumpAndSettle: ClickV2OnboardingPage's rows animate in via a
      // one-shot AnimationController, but held here mid-transition is enough
      // to confirm the push happened.
      await tester.tap(find.byKey(_clickV2RowKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(ClickV2OnboardingPage), findsOneWidget);
    });
  });

  group('gear overlay row', () {
    testWidgets('shown when a trainer app is configured', (tester) async {
      core.settings.setTrainerApp(SupportedApp.supportedApps.first);

      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();

      expect(find.byKey(_gearOverlayRowKey), findsOneWidget);
    });

    testWidgets('absent without a trainer app configured', (tester) async {
      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();

      expect(find.byKey(_gearOverlayRowKey), findsNothing);
    });

    testWidgets('tapping it opens a sheet with an overlay deep link when a trainer is known', (tester) async {
      core.settings.setTrainerApp(SupportedApp.supportedApps.first);
      final proxy = ProxyDevice(BleDevice(deviceId: 'trainer1', name: 'KICKR CORE'));

      await _pump(tester, devices: [proxy], connections: const []);
      await tester.pump();
      await _openSheet(tester, _gearOverlayRowKey);

      expect(find.text(l10n.helpCenterGearOverlayEntry), findsWidgets);
      expect(find.byKey(_overlayActionKey), findsOneWidget);
      expect(find.byKey(_vsBlogActionKey), findsOneWidget);

      // Not pumpAndSettle: ProxyDeviceDetailsPage subscribes to live
      // connection/device streams that never settle in a test harness.
      await _tapAction(tester, _overlayActionKey);
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      final page = tester.widget<ProxyDeviceDetailsPage>(find.byType(ProxyDeviceDetailsPage));
      // No virtual shifting session yet, so no gear to draw: the trainer's
      // page, where that session starts, rather than the Overlay page.
      expect(page.device, same(proxy));
    });

    testWidgets('shows the same numbered checks as the support intake, with the network test', (tester) async {
      core.settings.setTrainerApp(SupportedApp.supportedApps.first);

      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();
      await _openSheet(tester, _gearOverlayRowKey);

      expect(find.byType(HelpCheckList), findsOneWidget);
      for (final check in appNotReactingChecks(l10n)) {
        expect(find.text(check.title), findsOneWidget);
      }
      expect(find.text(l10n.helpAnswerGearBody), findsNothing);

      await _tapAction(tester, _networkTestActionKey);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(NetworkTroubleshootingPage), findsOneWidget);
    });

    testWidgets('falls back to the link-only fallback when no trainer is known', (tester) async {
      core.settings.setTrainerApp(SupportedApp.supportedApps.first);

      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();
      await _openSheet(tester, _gearOverlayRowKey);

      expect(find.byKey(_overlayActionKey), findsNothing);
      expect(find.byKey(_vsBlogActionKey), findsOneWidget);
    });

    testWidgets('the fallback action opens the virtual-shifting comparison blog post', (tester) async {
      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      core.settings.setTrainerApp(SupportedApp.supportedApps.first);

      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();
      await _openSheet(tester, _gearOverlayRowKey);

      await _tapAction(tester, _vsBlogActionKey);

      expect(
        fakeLauncher.launchedUrls,
        contains('https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol'),
      );
    });
  });

  // "My controller isn't found" used to need a controller that had been
  // paired before — exactly the rider who never got one to show up didn't
  // see it. It now shows whenever no controller is connected, together with
  // a way back into the setup guide. "Keeps disconnecting" still needs a
  // controller BikeControl has seen.
  group('controller disconnecting / not found rows', () {
    testWidgets('a known controller that is not connected gets both rows', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();

      expect(find.byKey(_controllerDisconnectingRowKey), findsOneWidget);
      expect(find.byKey(_controllerNotFoundRowKey), findsOneWidget);
      expect(find.byKey(_setupGuideRowKey), findsOneWidget);
    });

    testWidgets('with no controller at all, "isn\'t found" and the setup guide still show', (tester) async {
      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();

      expect(find.byKey(_controllerDisconnectingRowKey), findsNothing);
      expect(find.byKey(_controllerNotFoundRowKey), findsOneWidget);
      expect(find.byKey(_setupGuideRowKey), findsOneWidget);
    });

    testWidgets('a trainer alone does not count as a controller', (tester) async {
      final proxy = ProxyDevice(BleDevice(deviceId: 'trainer1', name: 'KICKR CORE'));

      await _pump(tester, devices: [proxy], connections: const []);
      await tester.pump();

      expect(find.byKey(_controllerDisconnectingRowKey), findsNothing);
      expect(find.byKey(_controllerNotFoundRowKey), findsOneWidget);
    });

    testWidgets('a connected controller drops "isn\'t found" and the setup guide', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'))..isConnected = true;

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();

      expect(find.byKey(_controllerDisconnectingRowKey), findsOneWidget);
      expect(find.byKey(_controllerNotFoundRowKey), findsNothing);
      expect(find.byKey(_setupGuideRowKey), findsNothing);
    });

    testWidgets('the disconnecting row opens a sheet linking to the Click V2 restart explainer', (tester) async {
      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();
      await _openSheet(tester, _controllerDisconnectingRowKey);

      expect(find.text(l10n.helpCenterControllerDisconnectingEntry), findsWidgets);
      expect(find.byKey(_clickV2RestartActionKey), findsOneWidget);

      await _tapAction(tester, _clickV2RestartActionKey);

      expect(
        fakeLauncher.launchedUrls,
        contains('https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps'),
      );
    });

    testWidgets('the not-found sheet ends with "Scan again" after the checks', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));
      var searches = 0;

      await _pump(tester, devices: [rightSide], connections: const [], onSearchAgain: () => searches++);
      await tester.pump();
      await _openSheet(tester, _controllerNotFoundRowKey);

      expect(find.text(l10n.helpCenterControllerNotFoundEntry), findsWidgets);
      expect(find.byType(HelpCheckList), findsOneWidget);
      expect(find.byKey(const ValueKey('help-answer-close')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(_searchAgainActionKey)).dy,
        greaterThan(tester.getBottomLeft(find.byType(HelpCheckList)).dy),
      );

      await _tapAction(tester, _searchAgainActionKey);
      await tester.pump(const Duration(milliseconds: 400));
      expect(searches, 1);
      expect(find.byType(HelpCheckList), findsNothing, reason: 'the sheet closes first');
    });

    testWidgets('"Still stuck?" opens support for the known controller', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));
      final asked = <String?>[];

      await _pump(tester, devices: [rightSide], connections: const [], onContactSupport: asked.add);
      await tester.pump();
      await _openSheet(tester, _controllerNotFoundRowKey);

      expect(find.text(l10n.helpAnswerStillStuckContactSupport), findsOneWidget);
      await _tapAction(tester, _contactSupportActionKey);
      await tester.pump(const Duration(milliseconds: 400));
      expect(asked, ['zwift_click_v2']);
    });

    testWidgets('a known Zwift controller gets the Zwift Companion firmware step', (tester) async {
      final rightSide = ZwiftClickV2RightSide(BleDevice(deviceId: 'r1', name: 'Zwift Click'));

      await _pump(tester, devices: [rightSide], connections: const []);
      await tester.pump();
      await _openSheet(tester, _controllerNotFoundRowKey);

      expect(find.text(l10n.zwiftCompanionApp), findsOneWidget);
    });

    testWidgets('with no known controller the not-found sheet does not assume Zwift', (tester) async {
      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();
      await _openSheet(tester, _controllerNotFoundRowKey);

      expect(find.text(l10n.zwiftCompanionApp), findsNothing);
      expect(find.text(l10n.helpCheckFirmwareMakerSub), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('nothing configured still offers the not-found answer and the setup guide', (tester) async {
      await _pump(tester, devices: const [], connections: const []);
      await tester.pump();

      expect(find.byKey(_networkRowKey), findsNothing);
      expect(find.byKey(_clickV2RowKey), findsNothing);
      expect(find.byKey(_gearOverlayRowKey), findsNothing);
      expect(find.byKey(_controllerDisconnectingRowKey), findsNothing);
      expect(find.byKey(_controllerNotFoundRowKey), findsOneWidget);
      expect(find.byKey(_setupGuideRowKey), findsOneWidget);
    });
  });
}
