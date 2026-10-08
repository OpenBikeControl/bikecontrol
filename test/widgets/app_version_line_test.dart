// The quiet "Version 7.1.0 · Patch 4 · Beta" line under Settings → App and
// at the bottom of the Help Center: the version as soon as it is known, the
// Shorebird patch once the updater reports one, the beta lane only when
// patches come from it, and a tap copies the line for support.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/app_version_line.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class _FakeSource extends ChangeNotifier implements AppVersionSource {
  _FakeSource({this.version, this.patch, this.onBetaTrack = false});

  @override
  String? version;
  @override
  int? patch;
  @override
  bool onBetaTrack;

  void update({String? version, int? patch, bool? onBetaTrack}) {
    this.version = version ?? this.version;
    this.patch = patch ?? this.patch;
    this.onBetaTrack = onBetaTrack ?? this.onBetaTrack;
    notifyListeners();
  }
}

Future<void> _pump(WidgetTester tester, AppVersionSource source) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: Scaffold(child: Center(child: AppVersionLine(source: source))),
    ),
  );
  await tester.pump();
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = await AppLocalizations.load(const Locale('en'));

  group('appVersionText', () {
    test('null before the version is known', () {
      expect(appVersionText(l, _FakeSource()), isNull);
    });

    test('just the version without a patch or beta lane', () {
      final text = appVersionText(l, _FakeSource(version: '7.1.0'))!;
      expect(text, l.version('7.1.0'));
    });

    test('adds the patch number when the updater reports one', () {
      final text = appVersionText(l, _FakeSource(version: '7.1.0', patch: 4))!;
      expect(text, startsWith(l.version('7.1.0')));
      expect(text, contains(l.versionPatch(4)));
      expect(text, isNot(contains(l.versionBetaTrack)));
    });

    test('names the beta lane only when on it', () {
      final beta = appVersionText(l, _FakeSource(version: '7.1.0', patch: 4, onBetaTrack: true))!;
      expect(beta, contains(l.versionPatch(4)));
      expect(beta, endsWith(l.versionBetaTrack));

      final noPatch = appVersionText(l, _FakeSource(version: '7.1.0', onBetaTrack: true))!;
      expect(noPatch, isNot(contains(l.versionPatch(0).split(' ').first)));
      expect(noPatch, endsWith(l.versionBetaTrack));
    });
  });

  group('AppVersionLine', () {
    testWidgets('draws nothing until the version is known, then fills in the patch', (tester) async {
      final source = _FakeSource();
      await _pump(tester, source);
      expect(find.byType(Text), findsNothing);

      source.update(version: '7.1.0');
      await tester.pump();
      expect(find.text(l.version('7.1.0')), findsOneWidget);

      source.update(patch: 4, onBetaTrack: true);
      await tester.pump();
      expect(find.text(appVersionText(l, source)!), findsOneWidget);
      expect(find.textContaining(l.versionPatch(4)), findsOneWidget);
      expect(find.textContaining(l.versionBetaTrack), findsOneWidget);
    });

    testWidgets('a tap copies the line to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final source = _FakeSource(version: '7.1.0', patch: 4);
      await _pump(tester, source);
      await tester.tap(find.byType(AppVersionLine));
      await tester.pump();
      expect(copied, appVersionText(l, source));
      // Let the confirmation toast time out.
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
