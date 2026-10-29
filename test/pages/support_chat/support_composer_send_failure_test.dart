import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression test for "sending a screenshot crashes the app".
///
/// The page-level send handlers rethrow so the composer knows to put the text
/// and the staged attachment back. The composer used to rethrow again — and
/// since the send button drops the returned Future, that escaped into the zone
/// as an unhandled error and was reported as "App crashed". The composer must
/// restore its state and stop there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A real (1x1) PNG — the chip renders it with Image.memory, which throws on
  // arbitrary bytes.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  StagedAttachment screenshot() => StagedAttachment(
    PlatformFile(
      name: 'screenshot.png',
      size: pngBytes.length,
      bytes: pngBytes,
    ),
  );

  Widget app({
    required Future<void> Function(String, List<StagedAttachment>) onSend,
    StagedAttachment? initialAttachment,
    String? initialText,
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
          onSend: onSend,
          initialText: initialText,
          initialAttachment: initialAttachment,
        ),
      ),
    );
  }

  testWidgets('a failed send with an attachment repopulates the composer and raises no zone error', (tester) async {
    // No FlutterError.onError override on purpose: flutter_test's zone already
    // captures unhandled async errors, so if _submit rethrows into the dropped
    // Future the framework surfaces it here and this test fails.
    var sends = 0;
    await tester.pumpWidget(
      app(
        initialText: 'please look at this',
        initialAttachment: screenshot(),
        onSend: (body, attachments) async {
          sends++;
          // Mirrors the page-level handlers: report, toast, rethrow.
          throw Exception('Failed to send message');
        },
      ),
    );
    await tester.pump();

    expect(find.text('screenshot.png'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(sends, 1);
    // Composer restored: the text is back and the attachment chip is still there.
    expect(find.text('screenshot.png'), findsOneWidget);
    final field = tester.widget<TextArea>(find.byType(TextArea));
    expect(field.controller!.text, 'please look at this');
    // And nothing leaked out as an unhandled error.
    expect(tester.takeException(), isNull);
  });

  testWidgets('an image-only message (empty body) can be sent', (tester) async {
    String? sentBody;
    List<StagedAttachment>? sentAttachments;
    await tester.pumpWidget(
      app(
        initialAttachment: screenshot(),
        onSend: (body, attachments) async {
          sentBody = body;
          sentAttachments = attachments;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(sentBody, '');
    expect(sentAttachments, hasLength(1));
    expect(tester.takeException(), isNull);
    // Sent successfully: the chip is gone.
    expect(find.text('screenshot.png'), findsNothing);
  });
}
