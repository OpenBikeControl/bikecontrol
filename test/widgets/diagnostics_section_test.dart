import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
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
  permissions: PermissionsSnapshot(localNetwork: LocalNetworkStatus.granted),
);

void main() {
  testWidgets('renders diagnostics text and fires refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
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
