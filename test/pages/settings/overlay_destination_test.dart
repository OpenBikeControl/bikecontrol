import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Where every "show me the overlay setup" lands — the Devices trainer row's
/// gear-overlay step, the self-test, the Help Center and the support intake:
/// the Overlay page, with its switch on screen, while the trainer is in a
/// virtual shifting session; the trainer's own page (where a session starts)
/// otherwise.
///
/// The step itself — when it is offered, that it blocks until answered, and
/// that "Not now" takes it off the card — is covered by chain_builder_test.dart
/// and home_page_test.dart; this pins down the other end of the link.
Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  /// A trainer with an active Virtual Shifting session (fitnessBike attached),
  /// which is what makes the Overlay section render at all.
  ProxyDevice makeVsDevice() {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'kickr',
        name: 'KICKR CORE',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
    device.debugAttachFitnessBike(
      FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: device.services!,
        data: ValueNotifier(''),
      ),
    );
    return device;
  }

  testWidgets('a shifting trainer lands on the Overlay page, switch on screen', (tester) async {
    final device = makeVsDevice();
    final destination = overlaySettingsDestination(device);
    expect(destination, isA<OverlaySettingsPage>());

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: destination,
      ),
    );
    await tester.pump();

    expect(find.byType(OverlaySettingsSection), findsOneWidget);
    // Hit-testable means the switch's label is on screen and nothing covers it.
    expect(find.text(AppLocalizations.current.overlayEnabled).hitTestable(), findsOneWidget);
  });

  test('a trainer without a session lands on its own page', () {
    final device = ProxyDevice(BleDevice(deviceId: 'kickr', name: 'KICKR CORE'));
    expect(overlaySettingsDestination(device), isA<ProxyDeviceDetailsPage>());
  });
}
