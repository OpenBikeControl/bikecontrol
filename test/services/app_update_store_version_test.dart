// Where the store-version check sends each platform, and when it counts as an
// update. Linux reads the version the CI publishes with its packages.
import 'package:bike_control/services/app_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:version/version.dart';

void main() {
  final current = Version.parse('7.4.1');

  test('a newer Linux release is a Linux download update', () {
    final update = storeUpdateFor('7.4.2', current, platform: TargetPlatform.linux);
    expect(update?.type, UpdateType.linuxDownload);
    expect(update?.version, Version.parse('7.4.2'));
  });

  test('the same or an older version is no update', () {
    expect(storeUpdateFor('7.4.1', current, platform: TargetPlatform.linux), isNull);
    expect(storeUpdateFor('7.3.9', current, platform: TargetPlatform.linux), isNull);
  });

  test('the other platforms keep their store', () {
    expect(storeUpdateFor('8.0.0', current, platform: TargetPlatform.windows)?.type, UpdateType.windowsStore);
    expect(storeUpdateFor('8.0.0', current, platform: TargetPlatform.android)?.type, UpdateType.playStore);
    expect(storeUpdateFor('8.0.0', current, platform: TargetPlatform.macOS)?.type, UpdateType.appStore);
  });

  test('the Linux version file and download page live on the rolling release', () {
    expect(linuxVersionUrl, 'https://github.com/OpenBikeControl/bikecontrol/releases/download/linux-latest/VERSION.txt');
    expect(linuxDownloadPage, 'https://github.com/OpenBikeControl/bikecontrol/releases/tag/linux-latest');
  });
}
