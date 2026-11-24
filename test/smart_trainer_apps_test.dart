import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/grimpa.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/smart_trainer_apps.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/wahoo.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every real trainer app links its smarttrainerapps.com entry with the BikeControl ref', () {
    final noEntry = {WahooApp, BikeControl, OpenBikeControl, CustomApp};
    for (final app in SupportedApp.supportedApps.where((a) => !noEntry.contains(a.runtimeType))) {
      final url = smartTrainerAppsUrl(app);
      expect(url, isNotNull, reason: app.name);
      expect(url.toString(), matches(RegExp(r'^https://smarttrainerapps\.com/apps/[a-z0-9-]+/\?ref=bikecontrol$')), reason: app.name);
    }
    expect(smartTrainerAppsUrl(MyWhoosh()).toString(), 'https://smarttrainerapps.com/apps/mywhoosh/?ref=bikecontrol');
  });

  test('only Grimpa has a rider deal: BIKECONTROL, 20% off', () {
    final deal = riderDealFor(Grimpa());
    expect(deal?.code, 'BIKECONTROL');
    expect(deal?.percentOff, 20);
    expect(SupportedApp.supportedApps.where((a) => riderDealFor(a) != null).map((a) => a.name), ['Grimpa']);
  });
}
