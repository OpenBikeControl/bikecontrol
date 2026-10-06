// A ride that can't be shared, saved or opened, or an FTP / max heart rate
// that can't be stored, used to fail silently: the error went to the log and
// the rider saw nothing happen. Each now also shows an error toast.
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, navigatorKey;
import 'package:bike_control/services/rides/ride_files.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/widgets/rides/ride_export.dart';
import 'package:bike_control/widgets/rides/ride_zone_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/ride_fixtures.dart';
import '../../helpers/ride_rig.dart';

class _FailingFiles implements RideFileActions {
  @override
  Future<bool> share(PastWorkout ride, Uint8List bytes, {Rect? origin}) async => throw const FileSystemException('share');

  @override
  Future<String?> save(PastWorkout ride, Uint8List bytes, {required String dialogTitle}) async =>
      throw const FileSystemException('save');

  @override
  Future<void> openFolder(Directory dir) async => throw const FileSystemException('open');
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.load(const Locale('en')));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    RideRig.reset();
    final real = RideFileActions.instance;
    RideFileActions.instance = _FailingFiles();
    addTearDown(() {
      RideFileActions.instance = real;
      debugHostPlatformOverride = null;
    });
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectToast(WidgetTester tester, String text) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(text), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  }

  for (final (row, label) in [
    ('ride-export-share', 'share'),
    ('ride-export-save', 'save'),
    ('ride-export-folder', 'open folder'),
  ]) {
    testWidgets('a failing $label shows a toast', (tester) async {
      debugHostPlatformOverride = TargetPlatform.macOS;
      final rig = await RideRig.install(store: null);
      final ride = await saveSampleRide(rig.repository);
      await pump(tester, SingleChildScrollView(child: RideExportRows(ride: ride)));

      await tester.tap(find.byKey(ValueKey(row)));
      await expectToast(tester, l10n.ridesExportFailed);
    });
  }

  testWidgets('an FTP that cannot be stored shows a toast', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Button.primary(
          onPressed: () => editRideZoneValue(
            context,
            title: 'FTP',
            body: '',
            unit: 'W',
            current: null,
            range: ftpRange,
            save: (_) async => throw StateError('disk full'),
            errorContext: 'test',
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ride-zone-value-field')), '250');
    await tester.tap(find.text(l10n.save));
    await expectToast(tester, l10n.ridesValueSaveFailed);
  });
}
