import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportedApp velotoss() =>
      SupportedApp.supportedApps.firstWhere((app) => app.name == 'Velotoss');

  test('Velotoss is registered as an official supported app', () {
    final matches =
        SupportedApp.supportedApps.where((app) => app.name == 'Velotoss');
    expect(matches, hasLength(1));
    expect(matches.first.officialIntegration, isTrue);
  });

  test('Velotoss connects via the OpenBikeControl protocol over the network', () {
    final app = velotoss();
    expect(app.supportLevel(AppConnectionMethod.obpMdns),
        ConnectionSupport.supported);
    expect(app.supportLevel(AppConnectionMethod.obpBle), isNull);
    // OBC delivers button events over the protocol, so there is no keyboard map.
    expect(app.keymap.keyPairs, isEmpty);
  });

  test('Velotoss finds trainers over Bluetooth only', () {
    expect(velotoss().virtualShiftingTransports,
        {TrainerConnectionType.bluetooth});
  });

  test('Velotoss ships a logo and links to velotoss.de', () {
    expect(velotoss().logoAsset, 'assets/velotoss.png');
    expect(velotoss().logoUrl,
        'https://bikecontrol.app/images/partners/velotoss-icon.png');
    expect(velotoss().officialUrl, 'https://velotoss.de');
  });
}
