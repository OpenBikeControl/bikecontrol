import 'dart:async';

import 'package:bike_control/bluetooth/devices/shimano/shimano_setup_sheet.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Which stage the Di2 guided sheet lands on for each way setup can fail, and
/// the D-Fly fallback it and the device panel offer.
void main() {
  Widget app(Widget child) => ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: child),
      );

  /// Opens the guided sheet the way the app does (as a bottom sheet), runs it
  /// into [error] and leaves it on the resulting stage.
  Future<void> runWith(WidgetTester tester, Object error, {VoidCallback? onUseDfly}) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => PrimaryButton(
            onPressed: () => openSheet<void>(
              context: context,
              position: OverlayPosition.bottom,
              builder: (_) => ShimanoGuidedSheet(
                title: 'Set up',
                intro: 'intro',
                successMessage: 'ok',
                confirmIcon: LucideIcons.slidersHorizontal,
                runningTitle: 'running',
                successTitle: 'done',
                checklistItems: const ['a', 'b'],
                initialPasskey: '000000',
                operation: (_) async => throw error,
                isUnresponsive: (e) => e is TimeoutException,
                isPasskeyRejected: (e) => e is ArgumentError,
                isPairingRequired: (e) => e is UnsupportedError,
                onUseDfly: onUseDfly,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(AppLocalizations.current.continueAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('pairing required → pair the Di2 in Windows Settings', (tester) async {
    await runWith(tester, UnsupportedError('not paired'), onUseDfly: () {});
    expect(find.text(AppLocalizations.current.shimanoPairTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoPairBody), findsOneWidget);
    expect(find.text(AppLocalizations.current.retry), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoGenericError), findsNothing);
  });

  testWidgets('pairing required → the rider can fall back to D-Fly channels', (tester) async {
    var usedDfly = false;
    await runWith(tester, UnsupportedError('not paired'), onUseDfly: () => usedDfly = true);

    await tester.tap(find.text(AppLocalizations.current.shimanoUseDfly));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(usedDfly, isTrue);
    expect(find.text(AppLocalizations.current.shimanoPairTitle), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('without a D-Fly fallback the pairing stage offers only Retry', (tester) async {
    await runWith(tester, UnsupportedError('not paired'));
    expect(find.text(AppLocalizations.current.shimanoPairTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoUseDfly), findsNothing);
  });

  testWidgets('no answer → wake your Di2', (tester) async {
    await runWith(tester, TimeoutException('asleep'));
    expect(find.text(AppLocalizations.current.shimanoAuthorizeTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoPairTitle), findsNothing);
  });

  testWidgets('any other failure → generic error', (tester) async {
    await runWith(tester, StateError('boom'));
    expect(find.text(AppLocalizations.current.shimanoGenericError), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoPairTitle), findsNothing);
  });

  group('passkey on a phone with the number pad up', () {
    // iPhone 12: 390×844 pt, number pad + safe area ≈ 336 pt.
    const keyboard = 336.0;

    Future<void> showKeyboard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await runWith(tester, ArgumentError('wrong passkey'));
      expect(find.text(AppLocalizations.current.shimanoPasskeyWrongTitle), findsOneWidget);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Retry stays above the keyboard', (tester) async {
      await showKeyboard(tester);
      final retry = tester.getRect(find.text(AppLocalizations.current.retry));
      expect(retry.bottom, lessThanOrEqualTo(844 - keyboard));
      expect(tester.takeException(), isNull);
    });

    testWidgets('entering all 6 digits closes the number pad', (tester) async {
      await showKeyboard(tester);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
    });

    testWidgets('tapping outside the field closes the number pad', (tester) async {
      await showKeyboard(tester);

      await tester.tap(find.text(AppLocalizations.current.shimanoPasskeyWrongTitle));
      await tester.pump();

      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
    });
  });

  group('device panel', () {
    Future<void> pumpPanel(WidgetTester tester, {required bool dfly, VoidCallback? onUseDfly}) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => shimanoSetupPanel(
              context,
              active: false,
              dfly: dfly,
              onSetup: () {},
              onTurnOff: () {},
              onUseDfly: onUseDfly ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('before deciding, offers button mode and the D-Fly fallback', (tester) async {
      var usedDfly = false;
      await pumpPanel(tester, dfly: false, onUseDfly: () => usedDfly = true);

      expect(find.text(AppLocalizations.current.shimanoSetup), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.shimanoUseDfly));
      expect(usedDfly, isTrue);
    });

    testWidgets('with D-Fly chosen, explains D-Fly and still offers button mode', (tester) async {
      await pumpPanel(tester, dfly: true);

      expect(find.text(AppLocalizations.current.shimanoDflyActive), findsOneWidget);
      expect(find.text(AppLocalizations.current.shimanoSetup), findsOneWidget);
      expect(find.text(AppLocalizations.current.shimanoUseDfly), findsNothing);
    });
  });
}
