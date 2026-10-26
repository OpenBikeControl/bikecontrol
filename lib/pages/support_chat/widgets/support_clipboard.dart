import 'dart:io' show File, Platform;
import 'dart:ui' as ui;

import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Reads what a paste into the support composer should attach, or null when
/// the paste should go into the text field as usual.
typedef ClipboardAttachmentReader = Future<StagedAttachment?> Function();

/// The default [ClipboardAttachmentReader]: a copied file (Finder/Explorer)
/// first, then text (left to the text field), then an image (a screenshot
/// or "Copy image"). Text beats the image because office apps put a
/// rendered picture of copied text on the clipboard next to the text itself.
Future<StagedAttachment?> readSupportClipboardAttachment() async {
  if (kIsWeb) return null;
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    for (final path in await Pasteboard.files()) {
      final file = File(path);
      final name = path.split(Platform.pathSeparator).last;
      if (SupportAttachmentLimits.mimeTypeForName(name) == null || !file.existsSync()) continue;
      return StagedAttachment(PlatformFile(name: name, path: path, size: file.lengthSync()));
    }
  }
  if ((await Clipboard.getData(Clipboard.kTextPlain))?.text?.isNotEmpty == true) return null;
  final image = await Pasteboard.image;
  if (image == null || image.isEmpty) return null;
  final png = await _asPng(image);
  final name = 'pasted-image-${DateTime.now().millisecondsSinceEpoch}.png';
  return StagedAttachment(PlatformFile(name: name, size: png.length, bytes: png));
}

/// Windows hands the clipboard image over as a BMP, which the upload
/// allowlist rejects: re-encode anything that isn't already a PNG.
Future<Uint8List> _asPng(Uint8List bytes) async {
  const pngMagic = [0x89, 0x50, 0x4E, 0x47];
  if (bytes.length > 4 && listEquals(bytes.sublist(0, 4), pngMagic)) return bytes;
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  return data!.buffer.asUint8List();
}
