import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/widgets/diagnostics_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/network_address.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

DebugDiagnostics _fixture() => const DebugDiagnostics(
      advertised: [],
      backend: 'nsd',
      hostLabel: null,
      holdsMulticastLock: false,
      discovered: [],
      discoveryRan: true,
      addressReport: AddressPickReport(chosen: null, candidates: []),
      servers: [],
      permissions: PermissionsSnapshot(
          bluetooth: 'granted', location: 'granted', localNetworkInferred: true),
    );

void main() {
  testWidgets('renders diagnostics text and fires refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: DiagnosticsSection(
            diagnostics: _fixture(),
            scanning: false,
            onRefresh: () => refreshed++,
          ),
        ),
      ),
    );

    expect(find.textContaining('Diagnostics:'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget); // header

    await tester.tap(find.byKey(const ValueKey('diagnostics-refresh')));
    await tester.pump();
    expect(refreshed, 1);
  });
}
