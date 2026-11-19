@Tags(['screenshots'])
library;

// The home screen's trainer-app row for an app without a bundled logo
// (Zwift): its initial, as in the onboarding's app picker, not a screen icon.
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/devices/chain_link_row.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/trainer_app_logo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  const link = ChainLink(
    key: ChainLinkKey.app,
    id: 'app',
    status: LinkStatus.attention,
    title: 'Zwift',
    steps: [
      SetupStep(id: SetupStepId.appSelected, done: true),
      SetupStep(id: SetupStepId.appConnectionMethod, done: true),
      SetupStep(id: SetupStepId.appConnected, done: false),
    ],
  );

  for (final brightness in Brightness.values) {
    testWidgets('trainer app row with a monogram (${brightness.name})', (tester) async {
      await captureWidget(tester, name: 'trainer_app_row_monogram_${brightness.name}', width: 390,
          locales: const ['de'], brightness: brightness,
          builder: (c) => BkGroupedSection(
                header: 'Trainer-App',
                children: [
                  ChainLinkRow(
                    link: link,
                    leading: const TrainerAppMonogram(name: 'Zwift'),
                    title: 'Zwift',
                    subtitle: 'Netzwerk',
                    appName: 'Zwift',
                    statusLabel: 'Warte auf die Verbindung von Zwift',
                    onTap: () {},
                    onInstructions: () {},
                  ),
                ],
              ));
      expect(find.text('Z'), findsOneWidget);
    });
  }
}
