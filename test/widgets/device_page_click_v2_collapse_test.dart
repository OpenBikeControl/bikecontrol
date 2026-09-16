import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/click_v2/onboarding_card.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Bare BLE scan result for one Click V2 side, mirroring the `_clickV2`
/// helper in test/zwift_clickv2_unlock_method_test.dart.
BleDevice _clickV2(int sideCode) => BleDevice(
  deviceId: 'click-$sideCode',
  name: 'Zwift Click',
  manufacturerDataList: [
    ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([sideCode])),
  ],
  services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
);

ZwiftClickV2LeftSide _leftSide() =>
    BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_LEFT_SIDE)) as ZwiftClickV2LeftSide;

ZwiftClickV2RightSide _rightSide() =>
    BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_RIGHT_SIDE)) as ZwiftClickV2RightSide;

/// No-op local-notifications backend, the same fake
/// test/integration/harness/test_env.dart installs. Only real plugin
/// registration sets the plugin's static platform instance, and
/// `resolvePlatformSpecificImplementation` reads it on every call, including
/// the notification permission check ScanWidget runs.
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    // ZwiftClickV2.unlockWarnings unconditionally calls
    // propPrefs.getZwiftClickV2LastUnlock before it even checks isConnected,
    // and PropPrefs' backing SharedPreferences is `late` -- so rendering any
    // Click V2 device card without this throws a LateInitializationError.
    // Production wires this up in Settings.init(); mirror it here.
    propPrefs.initialize(core.settings.prefs);
    // The split left/right representation (vs. the legacy unified device) is
    // gated by this setting. It defaults to true, but pin it explicitly so
    // BluetoothDevice.fromScanResult is guaranteed to hand back
    // ZwiftClickV2LeftSide / ZwiftClickV2RightSide here.
    await core.settings.setUseNewUnlockMethod(true);
    await AppLocalizations.load(const Locale('en'));
    // `core` is a process-wide singleton and every testWidgets below shares
    // it, so each test must start from a clean device list rather than
    // accumulating devices left over from a previous case.
    core.connection.devices.clear();

    // DevicePage always renders ScanWidget, whose initState synchronously
    // fires core.permissions.getScanRequirements(). Unmocked, that reaches
    // real platform code -- universal_ble's Bluetooth-availability check
    // and flutter_local_notifications' permission check -- that hangs or
    // throws in a plain widget test and trips flutter_test's "no pending
    // timers" / "no unhandled exceptions" invariants at teardown. Neutralize
    // both with the fakes test/integration/harness/test_env.dart installs for
    // the integration suite.
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
  });

  tearDown(() {
    core.connection.devices.clear();
  });

  Future<void> pumpDevicePage(WidgetTester tester, {required bool isMobile}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: SingleChildScrollView(
            child: DevicePage(
              onUpdate: () {},
              isMobile: isMobile,
              cardKeys: const {},
              footerBuilder: (device) => const SizedBox(),
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: an ordinary (not-yet-connected) device card's
    // StatusIcon shows SmallProgressIndicator, a perpetually spinning
    // animation -- pumpAndSettle would time out waiting for it to stop. A
    // couple of bounded pumps is enough to flush ScanWidget's initState
    // future (_checkRequirements, now backed by fakes/mocks above) and let
    // the resulting setState settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('both sides pending collapse into exactly one onboarding card', (tester) async {
    // Pending requires: onboarding not done, and not already settled on the
    // Zwift-unlock mode (a true value there can only come from a past
    // deliberate choice, per ClickV2Onboarding.isPending).
    await core.settings.setClickV2OnboardingDone(false);
    await core.settings.setUnlockWithZwift(false);
    core.connection.devices.add(_leftSide());
    core.connection.devices.add(_rightSide());

    await pumpDevicePage(tester, isMobile: false);

    expect(find.byType(ClickV2OnboardingCard), findsOneWidget);
    // Neither side gets its own device card -- both collapsed into the one
    // placeholder above.
    expect(find.text('Zwift Click V2 (left)'), findsNothing);
    expect(find.text('Zwift Click V2 (right)'), findsNothing);
  });

  testWidgets('only the left side pending still collapses into one onboarding card', (tester) async {
    await core.settings.setClickV2OnboardingDone(false);
    await core.settings.setUnlockWithZwift(false);
    core.connection.devices.add(_leftSide());
    // The right side isn't in range at all here -- one pending side is
    // enough to show the card, and there is still only ever one of them.

    await pumpDevicePage(tester, isMobile: false);

    expect(find.byType(ClickV2OnboardingCard), findsOneWidget);
    expect(find.text('Zwift Click V2 (left)'), findsNothing);
  });

  testWidgets('onboarding already done: no card, the side renders as an ordinary device card', (tester) async {
    // Regression guard for riders who already went through onboarding:
    // ClickV2Onboarding.isPending short-circuits on getClickV2OnboardingDone()
    // alone, so this must hold regardless of the unlockWithZwift setting.
    await core.settings.setClickV2OnboardingDone(true);
    core.connection.devices.add(_leftSide());

    await pumpDevicePage(tester, isMobile: false);

    expect(find.byType(ClickV2OnboardingCard), findsNothing);
    expect(find.text('Zwift Click V2 (left)'), findsOneWidget);
  });

  testWidgets('a Click V2 pair with onboarding done still pairs side by side on desktop', (tester) async {
    await core.settings.setClickV2OnboardingDone(true);
    core.connection.devices.add(_leftSide());
    core.connection.devices.add(_rightSide());

    await pumpDevicePage(tester, isMobile: false);

    expect(find.byType(ClickV2OnboardingCard), findsNothing);
    expect(find.text('Zwift Click V2 (left)'), findsOneWidget);
    expect(find.text('Zwift Click V2 (right)'), findsOneWidget);
    // _deviceGroups is private State, so the exact grouping can't be read
    // directly off the widget tree without reaching into DevicePage's
    // private state (not exposed) -- so this asserts a structural proxy
    // for "one row" instead of literally locating the shared Row.
    // DevicePage.build() inserts a Divider between device groups, skipped
    // after the *last* group ("if (index != deviceGroups.length - 1)").
    // With only these two devices present: paired into one group -> zero
    // Dividers; left unpaired as two separate single-device groups -> the
    // build would insert exactly one Divider between them. Zero Dividers
    // here is therefore direct evidence the two sides landed in the same
    // group (rendered side by side in one Row), not two stacked groups.
    expect(find.byType(Divider), findsNothing);
  });
}
