import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';

/// Sequences a standalone emulator's attach/start and stop/detach.
///
/// `DirconEmulator.startServer` advertises whatever is already attached to
/// its composite at the moment it is called. Calling it before the
/// definition is attached leaves the composite with no hostable service —
/// `BluetoothTransporter.start` refuses that outright with a `StateError`
/// ("refusing to start an empty peripheral") precisely to avoid the
/// alternative: a cryptic platform-level failure later (Windows rejects an
/// empty advertisement at `startAdvertising`; other transports would just
/// advertise a hollow peripheral). [stop] then [detachDefinition] the same
/// way round for the same reason in reverse: detaching before the transport
/// is stopped can race a live advertisement losing its only service out from
/// under a connected client.
///
/// Pulled out of the inline wiring in `connection.dart` purely so this
/// ordering has a test of its own — `connection.dart` cannot be constructed
/// in a unit test.
class StandaloneSensorLifecycle {
  StandaloneSensorLifecycle({
    required this.attachDefinition,
    required this.startServer,
    required this.stopServer,
    required this.detachDefinition,
  });

  final Future<void> Function(SensorDefinition) attachDefinition;
  final Future<void> Function(RetrofitMode) startServer;
  final Future<void> Function() stopServer;
  final Future<void> Function(SensorDefinition) detachDefinition;

  Future<void> start(SensorDefinition definition, RetrofitMode transport) async {
    await attachDefinition(definition);
    await startServer(transport);
  }

  Future<void> stop(SensorDefinition definition) async {
    await stopServer();
    await detachDefinition(definition);
  }
}
