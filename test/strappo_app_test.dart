import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportedApp strappo() =>
      SupportedApp.supportedApps.firstWhere((app) => app.name == 'Strappo');

  test('Strappo is registered as an official supported app', () {
    final matches =
        SupportedApp.supportedApps.where((app) => app.name == 'Strappo');
    expect(matches, hasLength(1));
    expect(matches.first.officialIntegration, isTrue);
  });

  test('Strappo connects via the OpenBikeControl protocol (mDNS + BLE)', () {
    final app = strappo();
    expect(app.supportLevel(AppConnectionMethod.obpMdns),
        ConnectionSupport.supported);
    expect(app.supportLevel(AppConnectionMethod.obpBle),
        ConnectionSupport.supported);
    // OBC delivers button events over the protocol, so there is no keyboard map.
    expect(app.keymap.keyPairs, isEmpty);
  });

  test('Strappo ships an official partner logo asset', () {
    expect(strappo().logoAsset, 'assets/strappo.png');
  });
}
