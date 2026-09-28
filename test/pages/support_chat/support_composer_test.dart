import 'dart:typed_data';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression test for the diagnostic-info sheet (the ⓘ button next to Send).
/// A real diagnostic payload includes the full log buffer, so the sheet grew
/// past the screen and left no barrier to tap — with no close button, drag
/// handle or back-route the user had to kill the app to escape.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  Widget app({
    String? payload,
    String? pinnedContext,
    String? pinnedContextLabel,
    StagedAttachment? initialAttachment,
    bool requireDescription = false,
    Future<void> Function(String body, StagedAttachment? attachment)? onSend,
  }) {
    return ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: SupportComposer(
          sending: false,
          onSend: onSend ?? (_, _) async {},
          diagnosticPreview: payload,
          pinnedContext: pinnedContext,
          pinnedContextLabel: pinnedContextLabel,
          initialAttachment: initialAttachment,
          requireDescription: requireDescription,
        ),
      ),
    );
  }

  /// The send button's enabled state: shadcn's [IconButton] is disabled iff
  /// `onPressed` is null, which is exactly how the composer gates it.
  bool sendEnabled(WidgetTester tester) {
    final button = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(LucideIcons.send), matching: find.byType(IconButton)),
    );
    return button.onPressed != null;
  }

  /// The ⓘ button next to Send (the notice also draws the info icon inline).
  Finder infoButton() => find.ancestor(of: find.byIcon(LucideIcons.info), matching: find.byType(Button)).first;
  const noScreenshotNotice = ValueKey('support-diagnostics-notice-no-screenshot');

  testWidgets('diagnostic sheet with a huge payload can be closed via its X button', (tester) async {
    // Realistic payload: JSON-encoded telemetry incl. hundreds of log lines.
    final payload = List.generate(400, (i) => '"log$i": "2026-07-09 10:00:$i - entry"').join('\n');
    await tester.pumpWidget(app(payload: payload));
    await tester.pump();

    await tester.tap(infoButton());
    await tester.pumpAndSettle();

    // Sheet is open; the raw payload sits behind the technical-details toggle.
    await tester.tap(find.text(l10n.supportDiagShowTechnical));
    await tester.pumpAndSettle();
    expect(find.textContaining('"log0"'), findsOneWidget);

    // It must offer an explicit close affordance that dismisses it.
    final close = find.byIcon(LucideIcons.x);
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.textContaining('"log0"'), findsNothing);
  });

  // GDPR transparency: when a support message will carry diagnostics (and, on
  // the first message, a screenshot), the composer must say so up front rather
  // than attaching them silently — a user should never be surprised by what
  // was sent. Ties to the "I never agreed to a screenshot" support ticket.
  // The notice names what actually goes out: a screenshot only when one is
  // staged.
  StagedAttachment png() => StagedAttachment(PlatformFile(name: 'bikecontrol-screenshot.png', size: 0));

  testWidgets('without a staged screenshot the notice only mentions diagnostics', (tester) async {
    await tester.pumpWidget(app(payload: 'App Version: 6.5.2'));
    await tester.pump();

    expect(find.byKey(noScreenshotNotice), findsOneWidget);
    expect(find.text(l10n.supportDiagnosticsNotice), findsNothing);
  });

  testWidgets('the notice points at the info button with the icon itself, not a text glyph', (tester) async {
    await tester.pumpWidget(app(payload: 'App Version: 6.5.2'));
    await tester.pump();
    expect(find.descendant(of: find.byKey(noScreenshotNotice), matching: find.byIcon(LucideIcons.info)), findsOneWidget);
    expect(find.textContaining('ⓘ', findRichText: true), findsNothing);
  });

  testWidgets('unknown summary values read "Unknown", not "?"', (tester) async {
    await tester.pumpWidget(app(payload: 'App Version: ?\nLogs:\na'));
    await tester.pump();
    await tester.tap(infoButton());
    await tester.pumpAndSettle();
    expect(find.text('?'), findsNothing);
    expect(find.text(l10n.unknown), findsNWidgets(2), reason: 'app version and platform');
  });

  testWidgets('with a staged screenshot the notice mentions it, until it is removed', (tester) async {
    await tester.pumpWidget(app(payload: 'App Version: 6.5.2', initialAttachment: png()));
    await tester.pump();
    expect(find.text(l10n.supportDiagnosticsNotice), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    expect(find.text(l10n.supportDiagnosticsNotice), findsNothing);
    expect(find.byKey(noScreenshotNotice), findsOneWidget);
  });

  testWidgets('hides the notice when there is no diagnostic payload', (tester) async {
    await tester.pumpWidget(app(payload: null));
    await tester.pump();

    expect(find.text(l10n.supportDiagnosticsNotice), findsNothing);
    expect(find.byKey(noScreenshotNotice), findsNothing);
  });

  testWidgets('the info sheet leads with a plain summary; the raw payload is behind a toggle', (tester) async {
    const payload = '''

---
App Version: 7.1.0+3
Update Track: stable
Platform: ios 18.2
Target: thisDevice
Trainer App: MyWhoosh
Connected Controllers: Zwift Click (fw 1.2)
Connected Trainers: OpenBikeControl
Smart Trainers:
  -
Status: Trial
Diagnostics: ok
Logs:
2026-09-28 10:00:01 - one
2026-09-28 10:00:02 - two
2026-09-28 10:00:03 - three''';
    await tester.pumpWidget(app(payload: payload, initialAttachment: png()));
    await tester.pump();
    await tester.tap(infoButton());
    await tester.pumpAndSettle();

    expect(find.text('7.1.0+3'), findsOneWidget);
    expect(find.text('ios 18.2'), findsOneWidget);
    expect(find.text('Zwift Click (fw 1.2)'), findsOneWidget);
    expect(find.text('OpenBikeControl'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'number of log lines');
    expect(find.text(l10n.supportDiagScreenshotAttached), findsOneWidget);
    expect(find.textContaining('10:00:01 - one'), findsNothing);

    await tester.tap(find.text(l10n.supportDiagShowTechnical));
    await tester.pumpAndSettle();
    expect(find.textContaining('10:00:01 - one'), findsOneWidget);
  });

  test('a JSON telemetry payload is summarised from its fields and free text', () {
    const json = '{"app_version": "7.1.0", "app_platform": "android", "bluetooth_name": "KICKR CORE", '
        '"freetext": "Connected Controllers: Zwift Ride\\nConnected Trainers: OpenBikeControl\\nLogs:\\na\\nb"}';
    final summary = SupportDiagnosticsSummary.parse(json);
    expect(summary.appVersion, '7.1.0');
    expect(summary.platform, 'android');
    expect(summary.devices, 'Zwift Ride');
    expect(summary.connections, 'OpenBikeControl');
    expect(summary.logLines, 2);
  });

  test('the summary is read from the diagnostics payload', () {
    final summary = SupportDiagnosticsSummary.parse('App Version: 1.0\nPlatform: android 15\nConnected Controllers: \nConnected Trainers: -\nLogs:\na\nb\n\nWire trace:\nx');
    expect(summary.appVersion, '1.0');
    expect(summary.platform, 'android 15');
    expect(summary.devices, isNull);
    expect(summary.connections, isNull);
    expect(summary.logLines, 2);
  });

  // Self-test → support hand-off. 93 of 309 chats in 30 days opened with a
  // bare "Network self-test: …" / "Resistance self-test: …" line and 62 of
  // them never said what was wrong — each one cost a "what actually isn't
  // working?" round trip. The result line still rides along, but it is
  // pinned below the input instead of prefilled into it, and send stays
  // disabled until the rider has typed at least a short description.
  group('pinnedContext', () {
    const pinned = 'Network self-test: NETWORK PASS';
    const label = 'network check result';

    testWidgets('renders the chip and keeps send disabled with no text', (tester) async {
      await tester.pumpWidget(app(pinnedContext: pinned, pinnedContextLabel: label));
      await tester.pump();

      expect(find.textContaining(label), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      // The pinned line is context for support, not something to edit: it
      // must not be prefilled into the input.
      expect(tester.widget<TextArea>(find.byType(TextArea)).controller!.text, isEmpty);
    });

    testWidgets('a two-character description is not enough and shows the hint', (tester) async {
      await tester.pumpWidget(app(pinnedContext: pinned, pinnedContextLabel: label));
      await tester.pump();

      await tester.enterText(find.byType(TextArea), 'hi');
      await tester.pump();

      expect(sendEnabled(tester), isFalse);
      expect(find.text(l10n.supportDescribeProblemHint), findsOneWidget);
    });

    testWidgets('whitespace-only text counts as no description', (tester) async {
      await tester.pumpWidget(app(pinnedContext: pinned, pinnedContextLabel: label));
      await tester.pump();

      await tester.enterText(find.byType(TextArea), '              \n   ');
      await tester.pump();

      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('a real description enables send and the body carries the pinned line last', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(
        app(
          pinnedContext: pinned,
          pinnedContextLabel: label,
          onSend: (body, _) async => sent.add(body),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextArea), 'MyWhoosh does not find BikeControl');
      await tester.pump();

      expect(sendEnabled(tester), isTrue);
      expect(find.text(l10n.supportDescribeProblemHint), findsNothing, reason: 'hint only shows while blocked');

      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(sent, ['MyWhoosh does not find BikeControl\n\nNetwork self-test: NETWORK PASS']);
    });

    testWidgets('a staged attachment does not bypass the description', (tester) async {
      // A non-image file: the chip then shows a file icon instead of trying
      // to decode the bytes, which is not what this test is about.
      final attachment = StagedAttachment(
        PlatformFile(name: 'bikecontrol.log', size: 3, bytes: Uint8List.fromList([1, 2, 3])),
      );
      await tester.pumpWidget(app(pinnedContext: pinned, pinnedContextLabel: label, initialAttachment: attachment));
      await tester.pump();

      expect(find.text('bikecontrol.log'), findsOneWidget, reason: 'the attachment is staged');
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('uses the describe-the-problem placeholder instead of the generic one', (tester) async {
      await tester.pumpWidget(app(pinnedContext: pinned, pinnedContextLabel: label));
      await tester.pump();

      expect(find.text(l10n.supportDescribeProblemPlaceholder), findsOneWidget);
      expect(find.text(l10n.messageComposerPlaceholder), findsNothing);
    });

    testWidgets('the pinned line rides along with the first send only', (tester) async {
      // A follow-up "yes, still happening" must not be blocked by the
      // 12-character gate, nor carry the (multi-line) test result again.
      final sent = <String>[];
      await tester.pumpWidget(
        app(
          pinnedContext: pinned,
          pinnedContextLabel: label,
          onSend: (body, _) async => sent.add(body),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextArea), 'MyWhoosh does not find BikeControl');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining(label), findsNothing, reason: 'chip is gone once the result has been sent');

      await tester.enterText(find.byType(TextArea), 'yes');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(sent, ['MyWhoosh does not find BikeControl\n\nNetwork self-test: NETWORK PASS', 'yes']);
    });

    testWidgets('a failed send restores the text and keeps the pinned line for the retry', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        app(
          pinnedContext: pinned,
          pinnedContextLabel: label,
          onSend: (body, _) async {
            attempts++;
            throw StateError('network down');
          },
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextArea), 'MyWhoosh does not find BikeControl');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      final field = tester.widget<TextArea>(find.byType(TextArea));
      expect(field.controller!.text, 'MyWhoosh does not find BikeControl', reason: 'only the typed text comes back');
      expect(find.textContaining(label), findsOneWidget, reason: 'the result is still attached for the retry');
    });

    testWidgets('without pinnedContext the composer behaves as before', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(app(onSend: (body, _) async => sent.add(body)));
      await tester.pump();

      expect(find.textContaining(label), findsNothing);
      expect(find.text(l10n.messageComposerPlaceholder), findsOneWidget);
      expect(sendEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextArea), 'hi');
      await tester.pump();
      expect(sendEnabled(tester), isTrue, reason: 'no 12-character gate without a pinned result');

      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();
      expect(sent, ['hi']);
    });
  });

  // A first message that is only a screenshot (the chat pre-stages one) told
  // support nothing about what went wrong. The first message of a
  // conversation needs a description; follow-ups may be attachment-only.
  group('requireDescription (first message)', () {
    StagedAttachment screenshot() => StagedAttachment(
      PlatformFile(name: 'ride-log.txt', size: 4, bytes: Uint8List.fromList([1, 2, 3, 4])),
    );

    testWidgets('an attachment alone cannot be sent, and the hint says why', (tester) async {
      await tester.pumpWidget(app(requireDescription: true, initialAttachment: screenshot()));
      await tester.pump();

      expect(sendEnabled(tester), isFalse);
      expect(find.text(l10n.supportDescribeProblemPlaceholder), findsOneWidget);
      expect(find.text(l10n.supportDescribeFirstMessageHint), findsOneWidget);

      await tester.enterText(find.byType(TextArea), 'help');
      await tester.pump();
      expect(sendEnabled(tester), isFalse, reason: 'too short to say what is wrong');

      await tester.enterText(find.byType(TextArea), 'MyWhoosh does not react to shifts');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
      expect(find.text(l10n.supportDescribeFirstMessageHint), findsNothing);
    });

    testWidgets('a follow-up may be attachment-only', (tester) async {
      await tester.pumpWidget(app(initialAttachment: screenshot()));
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
      expect(find.text(l10n.supportDescribeFirstMessageHint), findsNothing);
    });
  });
}
