import 'package:bike_control/bluetooth/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';

/// The wire trace must be recorded and exported for every user from the moment
/// [Connection.startLogCapture] runs — no entitlement involved.
///
/// The regression this guards: the trace used to be gated on the beta
/// entitlement at record time, but the entitlement stays unresolved until
/// IAP/Supabase finish initialising — minutes into a session on a cold start.
/// A tester's bundle then contained no `IN>`/`OUT<`/`trainer<`/`trainer>`
/// lines for exactly the connect, handshake and first-ride window it was
/// submitted to show. Note IAP is not initialised in this test either: an
/// entitlement lookup anywhere on this path would throw.
void main() {
  tearDown(() => Logger.onTrace = null);

  test('trace lines are exported from startLogCapture on, without any entitlement', () {
    final connection = Connection();
    connection.startLogCapture();

    Logger.trace(() => 'trainer< ftms 054a00');
    Logger.trace(() => 'trainer> 00002ad9 800501');

    expect(
      connection.lastTraceEntries.map((e) => e.entry),
      ['trainer< ftms 054a00', 'trainer> 00002ad9 800501'],
    );
  });
}
