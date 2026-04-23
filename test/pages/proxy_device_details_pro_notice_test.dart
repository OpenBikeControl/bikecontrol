import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/virtual_shifting_pro_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  testWidgets('shows virtual-shifting Pro note and Go Pro button', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const Scaffold(
          child: VirtualShiftingProNotice(trainerAppName: 'Zwift'),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Virtual shifting is a Pro feature'), findsOneWidget);
    expect(find.textContaining('20 min per day'), findsOneWidget);
    expect(find.text('Go Pro'), findsOneWidget);
  });
}
