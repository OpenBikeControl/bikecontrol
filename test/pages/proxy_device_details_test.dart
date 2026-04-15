import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.actionHandler = StubActions();
  });

  testWidgets('renders header with Smart Trainer title', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();

    expect(find.text('Smart Trainer'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Disconnect & forget'), findsOneWidget);
  });
}
