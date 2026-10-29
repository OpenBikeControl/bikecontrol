import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/widgets/support_message_group.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression test: an image attachment in a support-chat bubble was painted
/// on top of the following messages (reported on Windows, 7.2.0).
///
/// shadcn's [ChatGroup] sizes each group through `IntrinsicHeight`, and the
/// attachment preview wrapped its `Image.network` in a `LayoutBuilder`, which
/// cannot report intrinsic dimensions (release: 0, debug: throws). The group
/// therefore got the height of the text only, the bubble overflowed it and
/// the next group was laid out right over the screenshot.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tall desktop screenshot, like the one in the report (1900x1920),
  // scaled down so the test stays fast.
  late final Uint8List pngBytes;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 190, 192), Paint()..color = const Color(0xFF3366CC));
    final image = await recorder.endRecording().toImage(190, 192);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    pngBytes = data!.buffer.asUint8List();
  });

  final created = DateTime.utc(2026, 10, 14, 9, 9);

  SupportMessage message(String id, SupportMessageSenderRole role, String body, {bool withImage = false}) =>
      SupportMessage(
        id: id,
        chatId: 'chat',
        senderId: role.name,
        senderRole: role,
        body: body,
        parentMessageId: null,
        createdAt: created,
        attachments: [
          if (withImage)
            SupportAttachment(
              id: 'att-$id',
              messageId: id,
              storagePath: 'chat/$id/screenshot.png',
              fileName: 'screenshot.png',
              mimeType: 'image/png',
              createdAt: created,
            ),
        ],
      );

  testWidgets('an image attachment grows its bubble instead of overlapping the next message', (tester) async {
    HttpOverrides.global = _ServePng(pngBytes);
    addTearDown(() => HttpOverrides.global = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1400);
    addTearDown(tester.view.reset);

    final service = _FakeSupportChatService();
    final userMessage = message(
      'u1',
      SupportMessageSenderRole.user,
      'Hallo Jonas,\nhier ein Screenshot.',
      withImage: true,
    );
    final adminMessage = message('a1', SupportMessageSenderRole.admin, 'Hi Lukas,\ndanke dir!');

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: ListView(
            children: [
              SupportMessageGroup(key: const ValueKey('user'), messages: [userMessage], service: service),
              SupportMessageGroup(key: const ValueKey('admin'), messages: [adminMessage], service: service),
            ],
          ),
        ),
      ),
    );

    // Only the attachment preview, not the support avatar of the next group.
    final rawImage = find.descendant(of: find.byKey(const ValueKey('user')), matching: find.byType(RawImage));

    // Resolve the signed URL, then let the image download and decode for real.
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        if (rawImage.evaluate().isNotEmpty && tester.widget<RawImage>(rawImage).image != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(rawImage, findsOneWidget);
    expect(tester.widget<RawImage>(rawImage).image, isNotNull, reason: 'the attachment image should have loaded');

    final imageRect = tester.getRect(rawImage);
    expect(imageRect.height, greaterThan(100), reason: 'the preview shows the screenshot at a readable size');

    final userGroupRect = tester.getRect(find.byKey(const ValueKey('user')));
    final adminGroupRect = tester.getRect(find.byKey(const ValueKey('admin')));
    final timestamp = tester.getRect(
      find.descendant(of: find.byKey(const ValueKey('user')), matching: find.textContaining(':09')),
    );

    expect(userGroupRect.bottom, greaterThanOrEqualTo(imageRect.bottom), reason: 'the bubble must contain its image');
    expect(
      userGroupRect.bottom,
      greaterThanOrEqualTo(timestamp.bottom),
      reason: 'the bubble must contain its timestamp',
    );
    expect(timestamp.top, greaterThanOrEqualTo(imageRect.bottom), reason: 'the timestamp sits below the image');
    expect(
      adminGroupRect.top,
      greaterThanOrEqualTo(userGroupRect.bottom),
      reason: 'the next message must start below the bubble with the image',
    );
  });
}

class _FakeSupportChatService implements SupportChatService {
  @override
  Future<String> signedAttachmentUrl(String storagePath) async => 'https://storage.test/$storagePath';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers every request with [png] — enough of dart:io's HttpClient for
/// `Image.network` to download and decode a real image in a widget test.
class _ServePng extends HttpOverrides {
  _ServePng(this.png);
  final Uint8List png;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _PngClient(png);
}

class _PngClient implements HttpClient {
  _PngClient(this.png);
  final Uint8List png;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PngRequest(png);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PngRequest implements HttpClientRequest {
  _PngRequest(this.png);
  final Uint8List png;

  @override
  Future<HttpClientResponse> close() async => _PngResponse(png);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PngResponse extends Stream<List<int>> implements HttpClientResponse {
  _PngResponse(this.png);
  final Uint8List png;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => png.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(png).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
