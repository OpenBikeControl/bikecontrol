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

  testWidgets('diagnostic sheet with a huge payload can be closed via its X button', (tester) async {
    // Realistic payload: JSON-encoded telemetry incl. hundreds of log lines.
    final payload = List.generate(400, (i) => '"log$i": "2026-07-09 10:00:$i - entry"').join('\n');
    await tester.pumpWidget(app(payload: payload));
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.info));
    await tester.pumpAndSettle();

    // Sheet is open and shows the payload.
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
  testWidgets('shows the diagnostics/screenshot notice when a diagnostic payload is attached', (tester) async {
    await tester.pumpWidget(app(payload: 'app_version: 6.5.2'));
    await tester.pump();

    expect(find.text(l10n.supportDiagnosticsNotice), findsOneWidget);
  });

  testWidgets('hides the notice when there is no diagnostic payload', (tester) async {
    await tester.pumpWidget(app(payload: null));
    await tester.pump();

    expect(find.text(l10n.supportDiagnosticsNotice), findsNothing);
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
}
