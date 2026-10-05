import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/rides/ride_details_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_files.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/widgets/rides/ride_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_fixtures.dart';
import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

class _FakeFiles implements RideFileActions {
  final shared = <String>[];
  final saved = <String>[];
  final folders = <String>[];
  String? savePath = '/somewhere/ride.fit';

  @override
  Future<bool> share(PastWorkout ride, Uint8List bytes, {Rect? origin}) async {
    shared.add(ride.fileName);
    return true;
  }

  @override
  Future<String?> save(PastWorkout ride, Uint8List bytes, {required String dialogTitle}) async {
    saved.add(rideExportFileName(ride));
    return savePath;
  }

  @override
  Future<void> openFolder(Directory dir) async => folders.add(dir.path);
}

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l10n;
  late _FakeFiles files;
  setUpAll(() async => l10n = await AppLocalizations.load(const Locale('en')));

  setUp(() {
    RideRig.reset();
    files = _FakeFiles();
    final real = RideFileActions.instance;
    RideFileActions.instance = files;
    addTearDown(() {
      RideFileActions.instance = real;
      debugHostPlatformOverride = null;
    });
  });

  Future<void> pump(WidgetTester tester, PastWorkout ride) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: RideDetailsPage(ride: ride),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('values, the chart and Export', (tester) async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    final rig = await RideRig.install();
    final ride = await saveSampleRide(rig.repository);
    await pump(tester, ride);

    expect(find.text(l10n.ridesRideTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-stat-duration')), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-stat-distance')), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-stat-work')), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-stat-gears')), findsOneWidget);
    expect(find.textContaining('37', findRichText: true), findsWidgets);
    expect(find.byType(RideChartView), findsOneWidget);
    expect(find.text(l10n.ridesChartLegend), findsOneWidget);
    expect(find.text(l10n.ridesSaveFitIos), findsOneWidget);
    expect(find.text(l10n.miniWorkoutOpenFolder), findsNothing, reason: 'no folder on a phone');
  });

  testWidgets('no speed source: no distance, never an invented one', (tester) async {
    final rig = await RideRig.install(store: null);
    final ride = await saveSampleRide(rig.repository, speed: false);
    await pump(tester, ride);

    expect(find.byKey(const ValueKey('ride-stat-distance')), findsNothing);
    expect(find.text(l10n.miniWorkoutSummaryDistance), findsNothing);
  });

  testWidgets('no heart rate and no gears: those cells are left out', (tester) async {
    final rig = await RideRig.install(store: null);
    final ride = await saveSampleRide(rig.repository, heartRate: false, gearChanges: null);
    await pump(tester, ride);

    expect(find.byKey(const ValueKey('ride-stat-heart')), findsNothing);
    expect(find.byKey(const ValueKey('ride-stat-gears')), findsNothing);
  });

  testWidgets('iOS: Apple Health once, then a status, no second write', (tester) async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    final rig = await RideRig.install();
    final ride = await saveSampleRide(rig.repository);
    await pump(tester, ride);

    final store = healthStoreName(HealthStore.appleHealth, l10n);
    await tester.tap(find.text(l10n.ridesSaveToHealth(store)));
    await tester.pumpAndSettle();
    expect(rig.channel!.saved, hasLength(1));
    expect(find.text(l10n.ridesInHealth(store)), findsOneWidget);
    expect(find.text(l10n.ridesSaveToHealth(store)), findsNothing);

    await tester.tap(find.text(l10n.ridesInHealth(store)));
    await tester.pumpAndSettle();
    expect(rig.channel!.saved, hasLength(1));
  });

  testWidgets('Android without Health Connect: the row installs it', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    final rig = await RideRig.install(
      store: HealthStore.healthConnect,
      availability: HealthAvailability.notInstalled,
    );
    final ride = await saveSampleRide(rig.repository);
    await pump(tester, ride);

    expect(find.text(l10n.ridesHealthConnectNotInstalled), findsOneWidget);
    expect(find.text(l10n.ridesSaveFitAndroid), findsOneWidget);
    await tester.tap(find.text(l10n.ridesSaveToHealth('Health Connect')));
    await tester.pumpAndSettle();
    expect(rig.channel!.openInstallCalls, 1);
    expect(rig.channel!.saved, isEmpty);
  });

  testWidgets('desktop: no Health, save, share and the folder', (tester) async {
    debugHostPlatformOverride = TargetPlatform.macOS;
    final rig = await RideRig.install(store: null);
    final ride = await saveSampleRide(rig.repository);
    await pump(tester, ride);

    expect(find.text(l10n.ridesSaveToHealth(healthStoreName(HealthStore.appleHealth, l10n))), findsNothing);

    await tester.tap(find.text(l10n.ridesSaveFit));
    await tester.pumpAndSettle();
    expect(files.saved.single, startsWith('BikeControl '));
    expect(files.saved.single, endsWith('.fit'));
    expect((await rig.repository.find(ride.fileName))!.summary!.fitExported, isTrue);

    await tester.tap(find.text(l10n.miniWorkoutShareFit));
    await tester.pumpAndSettle();
    expect(files.shared.single, ride.fileName);

    await tester.tap(find.text(l10n.miniWorkoutOpenFolder));
    await tester.pumpAndSettle();
    expect(files.folders, hasLength(1));
  });

  testWidgets('a cancelled save marks nothing', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    final rig = await RideRig.install(store: null);
    final ride = await saveSampleRide(rig.repository);
    files.savePath = null;
    await pump(tester, ride);

    await tester.tap(find.text(l10n.ridesSaveFit));
    await tester.pumpAndSettle();
    expect((await rig.repository.find(ride.fileName))!.summary!.fitExported, isFalse);
  });

  testWidgets('delete from ⋯ asks first, then removes the ride', (tester) async {
    final rig = await RideRig.install();
    final ride = await saveSampleRide(rig.repository);
    await pump(tester, ride);

    await tester.tap(find.byKey(const ValueKey('ride-details-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ride-details-delete')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.ridesDeleteTitle), findsOneWidget);
    expect(find.text(l10n.ridesDeleteBody(healthStoreName(HealthStore.appleHealth, l10n))), findsOneWidget);
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();
    expect(await rig.repository.find(ride.fileName), isNull);
  });

  group('platform share', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(pathProvider, null);
    });

    test('sends the .fit under a readable name; a dismissed sheet is not an export', () async {
      final dir = await Directory.systemTemp.createTemp('ride-share-');
      addTearDown(() => dir.delete(recursive: true));
      messenger.setMockMethodCallHandler(pathProvider, (call) async => dir.path);
      final file = File('${dir.path}/workout-20261005T155600Z.fit')..writeAsBytesSync([1, 2, 3]);
      final ride = PastWorkout(file: file, startedAt: DateTime.utc(2026, 10, 5, 15, 56), sizeBytes: 3);
      final calls = <MethodCall>[];
      var result = 'dev.fluttercommunity.plus/share/success';
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return result;
      });

      expect(await PlatformRideFileActions().share(ride, Uint8List.fromList([1, 2, 3])), isTrue);
      final paths = (calls.single.arguments as Map)['paths'] as List;
      expect(paths.single, endsWith('.fit'));
      expect(paths.single, endsWith('BikeControl 2026-10-05 ${_localHm(ride.startedAt)}.fit'));
      expect(File(paths.single as String).readAsBytesSync(), [1, 2, 3]);

      result = ''; // the platform's "dismissed"
      expect(await PlatformRideFileActions().share(ride, Uint8List.fromList([1, 2, 3])), isFalse);
    });
  });
}

String _localHm(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.hour)}${two(l.minute)}';
}
