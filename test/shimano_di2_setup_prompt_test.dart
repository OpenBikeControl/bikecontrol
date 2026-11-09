import 'package:bike_control/bluetooth/devices/shimano/shimano_ble_transport.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/device_setup_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await core.settings.init();
  });

  // Hardware: the Di2 drops the link after a wrong passkey, and its reconnect
  // opened the setup a second time, on top of the one the rider had started
  // from the Di2 card.
  testWidgets('a Di2 setup the rider opened counts as offered', (tester) async {
    final di2 = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2-setup-offered'))
      ..debugUseConfigTransport(ShimanoBleTransport('di2-setup-offered', const []))
      ..isConnected = true;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: Builder(
            builder: (context) => PrimaryButton(onPressed: () => di2.openSetup(context), child: const Text('open')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(DeviceSetupPrompt.wasOffered(di2), isTrue);
  });
}
