// Shared setup for every test under test/. `flutter test` runs each test
// file's main() through [testExecutable] from the nearest
// flutter_test_config.dart; this is the only one in the package.
import 'dart:async';

import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/widgets/menu.dart' show debugDiagnosticsGatherOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/network_address.dart' show AddressPickReport;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Every recordError runs the real crash pipeline: a support-log line and a
  // persisted entry with a debug text. The diagnostics gather inside that
  // debug text does network and platform I/O that never completes in a widget
  // test's fake time, so its 6 s timeout would still be pending when the test
  // ends. Only the gather is faked; the rest of the pipeline stays real.
  //
  // Installed here for code that runs outside a test (main, setUpAll), and
  // again before each test. A test that needs the real gather sets
  // debugDiagnosticsGatherOverride to null in its own setUp or body; the next
  // test gets the fake back.
  debugDiagnosticsGatherOverride = _emptyDiagnostics;
  setUp(() {
    debugDiagnosticsGatherOverride = _emptyDiagnostics;
  });
  await testMain();
}

Future<DebugDiagnostics> _emptyDiagnostics({bool includeDiscovery = true}) async => const DebugDiagnostics(
  advertised: [],
  backend: 'faked by test/flutter_test_config.dart',
  hostLabel: null,
  holdsMulticastLock: false,
  discovered: [],
  discoveryRan: false,
  addressReport: AddressPickReport(chosen: null, candidates: []),
  servers: [],
  permissions: PermissionsSnapshot(localNetwork: null),
);
