import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/wahoo_element.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wahoo ELEMNT is registered in SupportedApp.supportedApps', () {
    expect(
      SupportedApp.supportedApps.whereType<WahooElement>(),
      hasLength(1),
    );
  });

  test('Wahoo ELEMNT declares only the di2Ble method as beta', () {
    final app = WahooElement();
    expect(app.connections, [
      (AppConnectionMethod.di2Ble, ConnectionSupport.beta),
    ]);
    expect(app.supportLevel(AppConnectionMethod.di2Ble), ConnectionSupport.beta);
    expect(app.supportLevel(AppConnectionMethod.zwiftBle), isNull);
  });
}
