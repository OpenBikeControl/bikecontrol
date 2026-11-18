import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> pumpLocalTile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(child: SingleChildScrollView(child: LocalTile(small: false))),
    ),
  );
  await tester.pump();
}

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
  });

  // In the video review a rider saw "Direct connection over the network" and
  // "Control MyWhoosh on this device" side by side, both recommended, and
  // skipped the screen: "no idea what all this means".
  testWidgets('next to an official connection, Local is marked optional and says why', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    await pumpLocalTile(tester);

    expect(find.text(l.chainOptional), findsOneWidget);
    expect(find.text(l.localControlOptionalDescription('MyWhoosh')), findsOneWidget);
  });

  testWidgets('for an app Local is the only way to reach, it stays the plain method', (tester) async {
    core.settings.setTrainerApp(CustomApp(profileName: 'Other'));
    await pumpLocalTile(tester);

    expect(find.text(l.chainOptional), findsNothing);
    expect(find.text(l.localControlOptionalDescription('Other')), findsNothing);
  });
}
