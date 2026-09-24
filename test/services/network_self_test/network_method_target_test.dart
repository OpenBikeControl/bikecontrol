import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart' show OpenBikeControlConstants;
import 'package:bike_control/services/network_self_test/network_method_target.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart' show kWahooDirconStandardPort;
import 'package:prop/mdns/service_advertiser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_advertiser.dart';

/// The self-test must examine the network method the selected trainer app
/// actually rides on. Rouvy never speaks OpenBikeControl: its method is the
/// Click server behind `core.rouvyMdnsEmulator`, so reading
/// `core.obpMdnsEmulator` for a Rouvy rider reported "not started" while the
/// Click server was listening and Rouvy was connected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServiceAdvertiser previousAdvertiser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    previousAdvertiser = ServiceAdvertiser.instance;
  });

  tearDown(() {
    ServiceAdvertiser.instance = previousAdvertiser;
    core.rouvyMdnsEmulator.isStarted.value = false;
    core.rouvyMdnsEmulator.isConnected.value = false;
    core.obpMdnsEmulator.isConnected.value = false;
  });

  group('resolveNetworkMethodTarget', () {
    test('Rouvy rides on the Click server, not OpenBikeControl', () {
      final target = resolveNetworkMethodTarget(Rouvy());

      expect(target.kind, NetworkMethodKind.rouvyMdns);
      expect(target.serverLabel, 'Click');
      expect(target.preferredPort, 36860);
      expect(target.isStarted, same(core.rouvyMdnsEmulator.isStarted));
      expect(target.isConnected, same(core.rouvyMdnsEmulator.isConnected));
    });

    test('MyWhoosh rides on OpenBikeControl', () {
      final target = resolveNetworkMethodTarget(MyWhoosh());

      expect(target.kind, NetworkMethodKind.openBikeControl);
      expect(target.serverLabel, 'OpenBikeControl');
      expect(target.preferredPort, OpenBikeControlConstants.TCP_PORT);
      expect(target.isStarted, same(core.obpMdnsEmulator.isStarted));
      expect(target.isConnected, same(core.obpMdnsEmulator.isConnected));
    });

    test('Zwift rides on the DirCon server', () {
      final target = resolveNetworkMethodTarget(Zwift());

      expect(target.kind, NetworkMethodKind.zwiftMdns);
      expect(target.serverLabel, 'DirCon');
      // Only "Other" (TrainerRoad) moves the bridge to the Wahoo standard port.
      expect(target.preferredPort, isNot(kWahooDirconStandardPort));
      expect(target.isStarted, same(core.zwiftMdnsEmulator.isStarted));
      expect(target.isConnected, same(core.zwiftMdnsEmulator.isConnected));
    });

    test('no trainer app selected falls back to OpenBikeControl', () {
      final target = resolveNetworkMethodTarget(null);

      expect(target.kind, NetworkMethodKind.openBikeControl);
      expect(target.serverLabel, 'OpenBikeControl');
    });

    test('currentNetworkMethodTarget reads the selected trainer app', () {
      core.settings.setTrainerApp(Rouvy());
      expect(currentNetworkMethodTarget().kind, NetworkMethodKind.rouvyMdns);

      core.settings.setTrainerApp(MyWhoosh());
      expect(currentNetworkMethodTarget().kind, NetworkMethodKind.openBikeControl);
    });

    test('a connected Rouvy is reported connected even though OBC is not', () {
      core.rouvyMdnsEmulator.isConnected.value = true;
      core.obpMdnsEmulator.isConnected.value = false;

      expect(resolveNetworkMethodTarget(Rouvy()).isConnected.value, isTrue);
      expect(resolveNetworkMethodTarget(MyWhoosh()).isConnected.value, isFalse);
    });
  });

  group('backend', () {
    test('Rouvy always registers through the in-process advertiser, whatever the OBC pref says', () async {
      // The OBC backend switch is per-service: only the OpenBikeControl
      // advertisement can be handed to the OS responder. Click stays on
      // ServiceAdvertiser.instance, so reporting the OBC pref here would
      // describe a record Rouvy never resolves.
      await core.settings.setObpMdnsBackend(ObpMdnsBackend.osResponder);

      expect(resolveNetworkMethodTarget(Rouvy()).backend, ObpMdnsBackend.platformDefault);
    });
  });

  group('advertisedHostname', () {
    test('Rouvy: null while the Click server is stopped', () {
      ServiceAdvertiser.instance = ResponderServiceAdvertiser(hostLabel: 'bikecontrol');
      core.rouvyMdnsEmulator.isStarted.value = false;

      expect(resolveNetworkMethodTarget(Rouvy()).advertisedHostname, isNull);
    });

    test('Rouvy: the responder host label once started', () {
      ServiceAdvertiser.instance = ResponderServiceAdvertiser(hostLabel: 'bikecontrol');
      core.rouvyMdnsEmulator.isStarted.value = true;

      expect(resolveNetworkMethodTarget(Rouvy()).advertisedHostname, 'bikecontrol.local');
    });

    test('Rouvy: null under an advertiser whose host record we cannot read back', () {
      ServiceAdvertiser.instance = RecordingAdvertiser();
      core.rouvyMdnsEmulator.isStarted.value = true;

      expect(resolveNetworkMethodTarget(Rouvy()).advertisedHostname, isNull);
    });
  });
}
