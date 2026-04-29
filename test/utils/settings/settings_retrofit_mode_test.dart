import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  group('Settings retrofit mode persistence', () {
    test('defaults to proxy when nothing stored', () {
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.proxy);
    });

    test('setRetrofitMode round-trips', () async {
      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.wifi);
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.wifi);

      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.bluetooth);
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.bluetooth);
    });

    test('distinct trainer keys store distinct modes', () async {
      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.wifi);
      await settings.setRetrofitMode('Zwift Hub 9876', RetrofitMode.bluetooth);

      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.wifi);
      expect(settings.getRetrofitMode('Zwift Hub 9876'), RetrofitMode.bluetooth);
    });

    test('unknown stored value falls back to proxy', () async {
      SharedPreferences.setMockInitialValues({'retrofit_mode_KICKR BIKE 1234': 'garbage'});
      final fresh = Settings();
      fresh.prefs = await SharedPreferences.getInstance();
      expect(fresh.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.proxy);
    });
  });
}
