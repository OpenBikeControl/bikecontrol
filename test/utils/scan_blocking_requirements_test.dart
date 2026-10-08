// Declining notifications must not stop BikeControl from looking for
// controllers. Notifications are asked for alongside the Bluetooth
// permissions, but every scan gate reads only the requirements a scan
// actually can't run without.
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  test('a missing notification permission does not block the scan', () {
    expect(Permissions.blockingScan([NotificationRequirement()]), isEmpty);
  });

  test('missing Bluetooth permissions still block it', () {
    final bluetooth = BluetoothTurnedOn();
    final location = LocationRequirement();
    expect(
      Permissions.blockingScan([bluetooth, NotificationRequirement(), location]),
      [bluetooth, location],
    );
  });
}
