import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportedApp byName(String name) =>
      SupportedApp.supportedApps.firstWhere((app) => app.name == name);

  test('trainer apps expose an https officialUrl for the chooser link', () {
    const named = [
      'Strappo',
      'MyWhoosh',
      'Rouvy',
      'Zwift',
      'Biketerra',
      'TrainingPeaks Virtual',
    ];
    for (final name in named) {
      final url = byName(name).officialUrl;
      expect(url, isNotNull, reason: '$name should link to its official site');
      expect(url, startsWith('https://'), reason: '$name url should be https');
    }
  });

  test('Strappo links to getstrappo.com', () {
    expect(byName('Strappo').officialUrl, 'https://getstrappo.com');
  });
}
