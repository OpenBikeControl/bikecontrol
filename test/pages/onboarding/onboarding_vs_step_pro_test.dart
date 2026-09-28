// The virtual-shifting step pitched BikeControl's virtual shifting without
// ever saying it is part of Pro — riders found out from the paywall after
// they had set it up. The step now carries the PRO badge and one honest line
// above the trainer list.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('the step says virtual shifting is Pro, with the trial and Base spelled out', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(
              builder: (c) => onboardingTrainerBody(
                c,
                app: MyWhoosh(),
                trainers: [ProxyDevice(BleDevice(deviceId: 'vs-pro', name: 'KICKR CORE'))],
                onPick: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.byType(ProBadge), findsOneWidget);
    expect(find.text(l.onboardingVsProNote('${core.bridgeUsageTracker.dailyLimit.inMinutes}')), findsOneWidget);
  });

  test('the "other device" target does not look like a controller', () {
    expect(Target.otherDevice.icon, isNot(LucideIcons.gamepad2));
  });
}
