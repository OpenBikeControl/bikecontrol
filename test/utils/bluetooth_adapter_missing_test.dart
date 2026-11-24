// A Windows PC without a Bluetooth radio: universal_ble reports
// `unsupported` (`unknown` while it is still starting up). The Bluetooth row
// used to fall through to "I guess Bluetooth is on now" and its Grant button
// did nothing. It now says the adapter is missing, offers Windows' Bluetooth
// settings, and no longer blocks the scan — Wi-Fi trainers and gamepads work
// without Bluetooth.
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../widget_snapshot.dart';

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

/// A radio that is there but refuses to be switched on (Windows: access
/// denied).
class _RefusingBle extends FakeUniversalBlePlatform {
  int enableCalls = 0;

  @override
  Future<bool> enableBluetooth() async {
    enableCalls++;
    throw PlatformException(code: 'Failed', message: 'Failed to enable bluetooth');
  }
}

class _FakeContext extends Fake implements BuildContext {}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  late _RefusingBle ble;
  late _FakeUrlLauncher urls;
  late bool wasScreenshotMode;

  setUp(() {
    ble = _RefusingBle();
    UniversalBle.setInstance(ble);
    urls = _FakeUrlLauncher();
    final previousUrls = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = urls;
    addTearDown(() => UrlLauncherPlatform.instance = previousUrls);
    wasScreenshotMode = screenshotMode;
    screenshotMode = false;
    debugHostPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    screenshotMode = wasScreenshotMode;
    debugHostPlatformOverride = null;
  });

  Future<BluetoothTurnedOn> probed(AvailabilityState state) async {
    ble.availability = state;
    final requirement = BluetoothTurnedOn();
    await requirement.getStatus();
    return requirement;
  }

  group('Windows without a Bluetooth adapter (unsupported)', () {
    test('is reported as a missing adapter, with a settings action', () async {
      final bluetooth = await probed(AvailabilityState.unsupported);
      final turnedOn = await probed(AvailabilityState.poweredOn);

      expect(bluetooth.status, isFalse);
      expect(bluetooth.adapterMissing, isTrue);
      expect(bluetooth.name, isNot(turnedOn.name));
      expect(bluetooth.description, isNotNull);
      expect(bluetooth.actionLabel, isNotNull);
      expect(bluetooth.isInformational, isTrue);
    });

    test('does not block the scan', () async {
      final bluetooth = await probed(AvailabilityState.unsupported);
      expect(Permissions.blockingScan([bluetooth]), isEmpty);
    });

    test('its action opens the Bluetooth settings and re-checks the status', () async {
      final bluetooth = await probed(AvailabilityState.unsupported);
      var updates = 0;
      await bluetooth.call(_FakeContext(), () => updates++);

      expect(urls.launchedUrls, ['ms-settings:bluetooth']);
      expect(updates, 1);
      expect(bluetooth.adapterMissing, isTrue);

      // An adapter plugged in meanwhile: the row turns back into the usual one.
      ble.availability = AvailabilityState.poweredOn;
      await bluetooth.getStatus();
      expect(bluetooth.status, isTrue);
      expect(bluetooth.adapterMissing, isFalse);
      expect(bluetooth.description, isNull);
      expect(bluetooth.actionLabel, isNull);
    });
  });

  test('unknown (plugin still starting) opens the Bluetooth settings', () async {
    final bluetooth = await probed(AvailabilityState.unknown);
    await bluetooth.call(_FakeContext(), () {});
    expect(urls.launchedUrls, ['ms-settings:bluetooth']);
  });

  group('radio off', () {
    test('still blocks the scan', () async {
      final bluetooth = await probed(AvailabilityState.poweredOff);
      expect(bluetooth.status, isFalse);
      expect(bluetooth.adapterMissing, isFalse);
      expect(bluetooth.actionLabel, isNull);
      expect(Permissions.blockingScan([bluetooth]), [bluetooth]);
    });

    test('a refused switch-on opens the Bluetooth settings instead of failing silently', () async {
      final bluetooth = await probed(AvailabilityState.poweredOff);
      var updates = 0;
      await bluetooth.call(_FakeContext(), () => updates++);

      expect(ble.enableCalls, 1);
      expect(urls.launchedUrls, ['ms-settings:bluetooth']);
      expect(updates, 1);
    });
  });

  test('radio on is granted and not a missing adapter', () async {
    final bluetooth = await probed(AvailabilityState.poweredOn);
    expect(bluetooth.status, isTrue);
    expect(bluetooth.adapterMissing, isFalse);
    expect(bluetooth.isInformational, isFalse);
  });

  test('unsupported on another platform is not relabelled', () async {
    debugHostPlatformOverride = TargetPlatform.android;
    final bluetooth = await probed(AvailabilityState.unsupported);
    expect(bluetooth.adapterMissing, isFalse);
    expect(Permissions.blockingScan([bluetooth]), [bluetooth]);
  });
}
