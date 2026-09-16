import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The deep-link target of the home screen's gear-overlay step ("{app} will
/// keep showing its own gear"): the trainer detail page, scrolled to the
/// Overlay section.
///
/// The step itself — when it is offered, that it blocks until answered, and
/// that "Not now" takes it off the card — is covered by chain_builder_test.dart
/// and home_page_test.dart; this pins down the other end of the link, so the
/// button cannot land the rider on a page where the switch is off screen.
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

  testWidgets('revealOverlaySection lands the rider on the Overlay section', (tester) async {
    final device = makeVsDevice();

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device, revealOverlaySection: true),
      ),
    );
    await tester.pump();
    // Let the post-frame ensureVisible scroll animation run out.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(OverlaySettingsSection), findsOneWidget);
    expect(find.text(AppLocalizations.current.overlayEnabled), findsOneWidget);
  });
}
