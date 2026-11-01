import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportedApp grimpa() =>
      SupportedApp.supportedApps.firstWhere((app) => app.name == 'Grimpa');

  test('Grimpa is registered as an official supported app', () {
    final matches =
        SupportedApp.supportedApps.where((app) => app.name == 'Grimpa');
    expect(matches, hasLength(1));
    expect(matches.first.officialIntegration, isTrue);
  });

  test('Grimpa connects via the OpenBikeControl protocol over Bluetooth', () {
    final app = grimpa();
    expect(app.supportLevel(AppConnectionMethod.obpBle),
        ConnectionSupport.supported);
    expect(app.supportLevel(AppConnectionMethod.obpMdns), isNull);
    // OBC delivers button events over the protocol, so there is no keyboard map.
    expect(app.keymap.keyPairs, isEmpty);
  });

  test('Grimpa finds trainers over Bluetooth only', () {
    expect(grimpa().virtualShiftingTransports,
        {TrainerConnectionType.bluetooth});
  });

  test('Grimpa lists the buttons it supports before it first connects', () {
    expect(
      grimpa().defaultObpSupportedButtons.map((b) => b.identifier).toList(),
      [0x01, 0x02, 0x03, 0x30, 0x31, 0x32, 0x33, 0x34, 0x38, 0x40],
    );
  });

  test('Grimpa ships a logo asset and links to grimpa.cc', () {
    expect(grimpa().logoAsset, 'assets/grimpa.png');
    expect(grimpa().officialUrl, 'https://www.grimpa.cc');
  });
}
