// A connection's state is a green dot, a spinner or nothing: colour and
// motion only. Screen readers get it as the icon's value.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<AppLocalizations> pump(WidgetTester tester, {required bool status, required bool started}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Center(child: StatusIcon(status: status, started: started, icon: LucideIcons.wifi)),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(StatusIcon)));
  }

  testWidgets('connected, connecting and off are spoken', (tester) async {
    final handle = tester.ensureSemantics();
    var l10n = await pump(tester, status: true, started: true);
    expect(find.semantics.byValue(l10n.statusConnected), findsOne);

    l10n = await pump(tester, status: false, started: true);
    expect(find.semantics.byValue(l10n.statusConnecting), findsOne);

    l10n = await pump(tester, status: false, started: false);
    expect(find.semantics.byValue(l10n.statusOff), findsOne);
    handle.dispose();
  });
}
