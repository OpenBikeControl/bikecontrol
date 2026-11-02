// The phone's update action: a bare refresh icon in the top bar told riders
// nothing, and a labelled button there squeezed the title — so it is a strip
// under the bar that says what is waiting and names the step: "Restart" for a
// downloaded patch, "Update" for a store version.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

Future<void> _pump(WidgetTester tester, AppUpdate update, {bool banner = true}) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        child: Center(
          child: AppUpdateButton(banner: banner, initialUpdate: update),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = await AppLocalizations.load(const Locale('en'));
  // Read once by the button on first mount; seeded so no platform call runs.
  packageInfoValue = PackageInfo(appName: 'BikeControl', packageName: 'app', version: '7.4.1', buildNumber: '1');

  final patch = AppUpdate(
    type: UpdateType.shorebird,
    version: Version(7, 4, 1, build: '3'),
  );
  final store = AppUpdate(type: UpdateType.appStore, version: Version(7, 5, 0));

  testWidgets('a downloaded patch asks for a restart on the phone', (tester) async {
    await _pump(tester, patch);
    expect(find.text(l.onboardingUpdateRestart), findsOneWidget);
    expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
    expect(find.text(l.appUpdatePatchReady), findsOneWidget);
  });

  testWidgets('a store version asks to update on the phone', (tester) async {
    await _pump(tester, store);
    expect(find.text(l.onboardingUpdateOpenStore), findsOneWidget);
    expect(find.text(l.onboardingUpdateRestart), findsNothing);
    expect(find.text(l.newVersionAvailableWithVersion('7.5.0')), findsOneWidget);
  });

  testWidgets('wider windows keep the full "New version available" label', (tester) async {
    await _pump(tester, store, banner: false);
    expect(find.text(l.newVersionAvailableWithVersion('7.5.0')), findsOneWidget);
  });
}
