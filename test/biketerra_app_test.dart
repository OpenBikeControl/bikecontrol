import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportedApp biketerra() =>
      SupportedApp.supportedApps.firstWhere((app) => app.name == 'Biketerra');

  test('Biketerra is registered as an official supported app', () {
    final matches =
        SupportedApp.supportedApps.where((app) => app.name == 'Biketerra');
    expect(matches, hasLength(1));
    expect(matches.first.officialIntegration, isTrue);
  });

  test('Biketerra connects via OpenBikeControl over Bluetooth', () {
    final app = biketerra();
    expect(app.supportLevel(AppConnectionMethod.obpBle),
        ConnectionSupport.supported);
    // No network flavour of the protocol.
    expect(app.supportLevel(AppConnectionMethod.obpMdns), isNull);
    expect(app.supportLevel(AppConnectionMethod.obpDirCon), isNull);
  });

  test('Biketerra ships an official partner logo with a network fallback', () {
    final app = biketerra();
    expect(app.logoAsset, 'assets/biketerra.png');
    expect(app.logoUrl,
        'https://bikecontrol.app/images/partners/biketerra-icon.png');
  });

  test('Biketerra takes a Virtual Shifting trainer over Bluetooth only', () {
    // Biketerra has no WiFi (DirCon) trainer connection, so offering the WiFi
    // bridge leaves the rider on a transport it never finds.
    expect(biketerra().virtualShiftingTransports, {TrainerConnectionType.bluetooth});
  });
}
