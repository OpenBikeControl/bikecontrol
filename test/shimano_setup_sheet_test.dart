import 'dart:async';

import 'package:bike_control/bluetooth/devices/shimano/shimano_setup_sheet.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show ShimanoShifter;
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
  Future<void> runWith(WidgetTester tester, Object error, {VoidCallback? onUseDfly, VoidCallback? onUseButtonMode}) async {
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
                isWiredShifters: (e) => e is FormatException,
                isRejected: (e) => e is ConcurrentModificationError,
                onUseDfly: onUseDfly,
                onUseButtonMode: onUseButtonMode,
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

  testWidgets('wired shifters → E-TUBE channels do not work with them, button mode does', (tester) async {
    var usedButtonMode = false;
    await runWith(tester, const FormatException('wired'), onUseButtonMode: () => usedButtonMode = true);
    expect(find.text(AppLocalizations.current.shimanoWiredTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoWiredBody), findsOneWidget);
    expect(find.text(AppLocalizations.current.retry), findsNothing, reason: 'trying again cannot work');

    await tester.tap(find.text(AppLocalizations.current.shimanoUseButtonMode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(usedButtonMode, isTrue);
    expect(find.text(AppLocalizations.current.shimanoWiredTitle), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('wired shifters → the D-Fly channels set in E-TUBE can be used instead', (tester) async {
    var usedDfly = false;
    await runWith(tester, const FormatException('wired'), onUseDfly: () => usedDfly = true, onUseButtonMode: () {});
    expect(find.text(AppLocalizations.current.shimanoWiredTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoUseButtonMode), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.shimanoUseDfly));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(usedDfly, isTrue);
    expect(find.text(AppLocalizations.current.shimanoWiredTitle), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('a shifter that turned the setting down → set the channels in E-TUBE, or button mode', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var usedButtonMode = false;
    await runWith(tester, ConcurrentModificationError(), onUseDfly: () {}, onUseButtonMode: () => usedButtonMode = true);
    expect(find.text(AppLocalizations.current.shimanoRejectedTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoRejectedBody), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoUseDfly), findsOneWidget);
    expect(find.text(AppLocalizations.current.retry), findsNothing, reason: 'trying again cannot work');

    await tester.tap(find.text(AppLocalizations.current.shimanoUseButtonMode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(usedButtonMode, isTrue);
    expect(find.text(AppLocalizations.current.shimanoRejectedTitle), findsNothing, reason: 'the sheet closes');
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
    Future<List<String>> pumpPanel(
      WidgetTester tester, {
      bool buttonMode = false,
      bool channels = false,
      bool canRestore = false,
      bool showButtonModeWarning = false,
    }) async {
      final taps = <String>[];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => shimanoSetupPanel(
              context,
              buttonMode: buttonMode,
              channels: channels,
              canRestore: canRestore,
              showButtonModeWarning: showButtonModeWarning,
              onSetup: () => taps.add('setup'),
              onRestore: () => taps.add('restore'),
              onTurnOff: () => taps.add('turnOff'),
              onSwitchToChannels: () => taps.add('channels'),
              onDismissWarning: () => taps.add('dismiss'),
            ),
          ),
        ),
      );
      await tester.pump();
      return taps;
    }

    testWidgets('before setup, offers the setup', (tester) async {
      final taps = await pumpPanel(tester);

      await tester.tap(find.text(AppLocalizations.current.shimanoSetup));
      expect(taps, ['setup']);
      expect(find.text(AppLocalizations.current.shimanoRestore), findsNothing);
    });

    testWidgets('with E-TUBE channels set by BikeControl, offers to restore the shifting', (tester) async {
      final taps = await pumpPanel(tester, channels: true, canRestore: true);

      expect(find.text(AppLocalizations.current.shimanoChannelsActive), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.shimanoRestore));
      await tester.tap(find.text(AppLocalizations.current.shimanoChangeSetup));
      expect(taps, ['restore', 'setup']);
    });

    testWidgets('with D-Fly channels set in E-TUBE, there is nothing to restore', (tester) async {
      await pumpPanel(tester, channels: true);

      expect(find.text(AppLocalizations.current.shimanoDflyActive), findsOneWidget);
      expect(find.text(AppLocalizations.current.shimanoRestore), findsNothing);
    });

    testWidgets('button mode warns that a disconnect shifts for real, until dismissed', (tester) async {
      final taps = await pumpPanel(tester, buttonMode: true, showButtonModeWarning: true);

      expect(find.text(AppLocalizations.current.shimanoButtonModeWarning), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.shimanoSwitchToChannels));
      await tester.tap(find.text(AppLocalizations.current.gotIt));
      expect(taps, ['channels', 'dismiss']);

      await pumpPanel(tester, buttonMode: true);
      expect(find.text(AppLocalizations.current.shimanoButtonModeWarning), findsNothing);
    });
  });

  group('mode choice', () {
    testWidgets('recommends E-TUBE channels and hands over the choice', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ShimanoSetupMode? chosen;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => PrimaryButton(
              onPressed: () => showShimanoModeChooser(context, onChoose: (mode) => chosen = mode),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(AppLocalizations.current.recommended), findsOneWidget);
      expect(find.text(AppLocalizations.current.shimanoModeButtonsWarning), findsOneWidget);

      await tester.ensureVisible(find.text(AppLocalizations.current.shimanoModeButtonsTitle));
      await tester.pump();
      await tester.tap(find.text(AppLocalizations.current.shimanoModeButtonsTitle));
      await tester.pump();
      await tester.ensureVisible(find.text(AppLocalizations.current.continueAction));
      await tester.pump();
      await tester.tap(find.text(AppLocalizations.current.continueAction));
      await tester.pumpAndSettle();

      expect(chosen, ShimanoSetupMode.buttons);
    });
  });

  testWidgets('while the shifters are read and saved, the sheet asks for a press on each', (tester) async {
    final shifters = ValueNotifier<ShimanoShifterAsk?>(null);
    final operation = Completer<void>();
    var cancelled = false;
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
                confirmIcon: LucideIcons.radio,
                runningTitle: 'running',
                successTitle: 'done',
                checklistItems: const ['a', 'b'],
                initialPasskey: '000000',
                operation: (_) => operation.future,
                isUnresponsive: (e) => false,
                isPasskeyRejected: (e) => false,
                isPairingRequired: (e) => false,
                shifters: shifters,
                onCancelShifters: () => cancelled = true,
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

    expect(find.text(AppLocalizations.current.shimanoPressShiftersTitle), findsNothing);
    shifters.value = const ShimanoShifterAsk({});
    await tester.pump();
    expect(find.text(AppLocalizations.current.shimanoPressShiftersTitle), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsNothing);

    expect(find.text(AppLocalizations.current.shimanoOneShifterHint), findsNothing);

    shifters.value = const ShimanoShifterAsk({ShimanoShifter.left});
    await tester.pump();
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    // Once one shifter is in, a rider with only that one learns to wait.
    expect(find.text(AppLocalizations.current.shimanoOneShifterHint), findsOneWidget);

    shifters.value = const ShimanoShifterAsk({}, saving: true, next: ShimanoShifter.left);
    await tester.pump();
    expect(find.text(AppLocalizations.current.shimanoSaveShiftersTitle), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
    // The right shifter waits until the left one is saved.
    expect(find.byIcon(LucideIcons.hourglass), findsOneWidget);

    // A Di2 with one shifter: one prompt, no side named.
    shifters.value = const ShimanoShifterAsk({}, saving: true, next: ShimanoShifter.left, single: true);
    await tester.pump();
    expect(find.text(AppLocalizations.current.shimanoSaveShifterTitle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoShifterSingle), findsOneWidget);
    expect(find.text(AppLocalizations.current.shimanoShifterLeft), findsNothing);
    expect(find.text(AppLocalizations.current.shimanoShifterRight), findsNothing);
    expect(find.byIcon(LucideIcons.hourglass), findsNothing);

    shifters.value = null;
    operation.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('done'), findsOneWidget);
    expect(cancelled, isFalse);
  });

  testWidgets('while the sheet waits for the shifters, cancel stops and closes it', (tester) async {
    final shifters = ValueNotifier<ShimanoShifterAsk?>(null);
    final operation = Completer<void>();
    var cancelled = false;
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
                confirmIcon: LucideIcons.radio,
                runningTitle: 'running',
                successTitle: 'done',
                checklistItems: const ['a', 'b'],
                initialPasskey: '000000',
                operation: (_) => operation.future,
                isUnresponsive: (e) => false,
                isPasskeyRejected: (e) => false,
                isPairingRequired: (e) => false,
                shifters: shifters,
                onCancelShifters: () {
                  cancelled = true;
                  operation.completeError(const ShimanoSetupCancelled());
                },
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
    shifters.value = const ShimanoShifterAsk({}, saving: true);
    await tester.pump();

    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(find.text(AppLocalizations.current.shimanoSaveShiftersTitle), findsNothing);
  });

  group('a save step that does not finish', () {
    late ValueNotifier<ShimanoShifterAsk?> shifters;
    late Completer<void> operation;
    late bool cancelled;

    Future<void> openSaving(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      shifters = ValueNotifier<ShimanoShifterAsk?>(null);
      operation = Completer<void>();
      cancelled = false;
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
                  confirmIcon: LucideIcons.radio,
                  runningTitle: 'running',
                  successTitle: 'done',
                  checklistItems: const ['a', 'b'],
                  initialPasskey: '000000',
                  operation: (_) => operation.future,
                  isUnresponsive: (e) => e is TimeoutException,
                  isPasskeyRejected: (e) => false,
                  isPairingRequired: (e) => false,
                  isRejected: (e) => false,
                  onUseDfly: () {},
                  onUseButtonMode: () {},
                  shifters: shifters,
                  onCancelShifters: () {
                    cancelled = true;
                    operation.completeError(const ShimanoSetupCancelled());
                  },
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
      shifters.value = const ShimanoShifterAsk({}, saving: true, next: ShimanoShifter.right, single: true);
      await tester.pump();
    }

    testWidgets('after a while it offers the E-TUBE app, which stops the setup and shows how', (tester) async {
      await openSaving(tester);
      expect(find.text(AppLocalizations.current.shimanoUseEtubeInstead), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text(AppLocalizations.current.shimanoUseEtubeInstead), findsOneWidget);

      await tester.tap(find.text(AppLocalizations.current.shimanoUseEtubeInstead));
      shifters.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(cancelled, isTrue);
      expect(find.text(AppLocalizations.current.shimanoRejectedTitle), findsOneWidget);
      expect(find.text(AppLocalizations.current.shimanoUseButtonMode), findsOneWidget);
    });

    testWidgets('a failure there ends on the E-TUBE app, not on waking the Di2', (tester) async {
      await openSaving(tester);
      operation.completeError(TimeoutException('no confirm'));
      shifters.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(AppLocalizations.current.shimanoRejectedTitle), findsOneWidget);
    });
  });
}
