// A controller press lights its button on the home card. It used to do that by
// rebuilding the whole home page (and, through the activity log, the whole
// overview around it) on every press; only the pressed button should rebuild.
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:flutter/widgets.dart' as w;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() => core.settings.setTrainerApp(MyWhoosh()));
  tearDown(() => core.connection.devices.clear());

  testWidgets('a controller press rebuilds its button, not the home page', (tester) async {
    const button = ControllerButton('shiftUpRight');
    final device = HidDevice('Keyboard')..isConnected = true;
    device.availableButtons.add(button);
    core.connection.devices.add(device);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: SingleChildScrollView(child: HomePage(isMobile: true, onUpdate: () {})),
        ),
      ),
    );
    await tester.pump();

    int pressGeneration() => tester
        .widgetList<AnimatedButtonWidget>(find.byType(AnimatedButtonWidget))
        .firstWhere((b) => b.button.name == button.name)
        .pressGeneration;
    expect(pressGeneration(), 0);

    final homeRebuilds = <w.Element>[];
    w.debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is HomePage) homeRebuilds.add(element);
    };
    addTearDown(() => w.debugOnRebuildDirtyWidget = null);

    core.connection.signalNotification(ButtonNotification(device: device, buttonsClicked: [button]));
    await tester.pump();

    expect(pressGeneration(), 1, reason: 'the pressed button still lights up');
    expect(homeRebuilds, isEmpty, reason: 'a press must not rebuild the whole home page');
  });
}
