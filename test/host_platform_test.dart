// The host-platform seam: feature gates that depend on the operating system
// read it instead of dart:io's Platform, so a test can stage the Android (or
// iOS) build on a desktop test host. Off by default: without an override the
// gates see the real host.
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/home_extras.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  tearDown(() {
    debugHostPlatformOverride = null;
    core.actionHandler = StubActions();
  });

  test('without an override it is the real host', () {
    expect(HostPlatform.isAndroid, Platform.isAndroid);
    expect(HostPlatform.isIOS, Platform.isIOS);
    expect(HostPlatform.isMacOS, Platform.isMacOS);
    expect(HostPlatform.isWindows, Platform.isWindows);
  });

  test('an override stands in for the host', () {
    debugHostPlatformOverride = TargetPlatform.android;
    expect(HostPlatform.isAndroid, isTrue);
    expect(HostPlatform.isIOS, isFalse);
    expect(HostPlatform.isMacOS, isFalse);
    expect(HostPlatform.isWindows, isFalse);
  });

  test('an Android build with the accessibility service can run it', () {
    core.actionHandler = AndroidActions();
    debugHostPlatformOverride = TargetPlatform.android;
    expect(core.logic.canRunAndroidService, isTrue);
    debugHostPlatformOverride = TargetPlatform.iOS;
    expect(core.logic.canRunAndroidService, isFalse);
  });

  test('local control on an Android build asks for the accessibility service', () {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setLastTarget(Target.thisDevice);
    debugHostPlatformOverride = TargetPlatform.android;
    expect(core.logic.showLocalControl, isTrue);
    expect(core.permissions.getLocalControlRequirements().single, isA<AccessibilityRequirement>());
    debugHostPlatformOverride = TargetPlatform.iOS;
    expect(core.logic.showLocalControl, isFalse);
  });

  testWidgets('phone steering is offered on an Android build, not on a desktop one', (tester) async {
    Future<void> pump() async {
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [
            ...ShadcnLocalizations.localizationsDelegates,
            OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: snapshotTheme(Brightness.light),
          home: SingleChildScrollView(child: HomeExtras(isMobile: true, onUpdate: () {})),
        ),
      );
      await tester.pump();
    }

    debugHostPlatformOverride = TargetPlatform.android;
    await pump();
    expect(find.text(AppLocalizations.current.enableSteeringWithPhone), findsOneWidget);
    expect(find.text(AppLocalizations.current.enableMediaKeyDetection), findsNothing);

    debugHostPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(const SizedBox());
    await pump();
    expect(find.text(AppLocalizations.current.enableSteeringWithPhone), findsNothing);
  });
}
