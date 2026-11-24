import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

typedef DirectoryPicker = Future<String?> Function({String? initialDirectory, String? dialogTitle});

/// The user's Pictures folder, used as the starting point for the screenshot
/// folder picker. Never the process working directory: on Windows that is
/// whatever folder BikeControl was launched from (often an install folder).
String? defaultScreenshotDirectory({required Map<String, String> environment, required bool isWindows}) {
  final home = isWindows ? environment['USERPROFILE'] : environment['HOME'];
  if (home == null || home.trim().isEmpty) return null;
  final separator = isWindows ? r'\' : '/';
  final base = home.endsWith(separator) ? home.substring(0, home.length - 1) : home;
  return '$base${separator}Pictures';
}

/// Lets the user pick the screenshot folder. Starts at [current] if it exists,
/// otherwise at [fallback]. Returns null when the user cancels.
Future<String?> chooseScreenshotDirectory({
  required String? current,
  required String? fallback,
  required DirectoryPicker pick,
  String? dialogTitle,
}) async {
  String? initial;
  for (final candidate in [current, fallback]) {
    final path = candidate?.trim();
    if (path != null && path.isNotEmpty && Directory(path).existsSync()) {
      initial = path;
      break;
    }
  }
  final picked = (await pick(initialDirectory: initial, dialogTitle: dialogTitle))?.trim();
  if (picked == null || picked.isEmpty) return null;
  return picked;
}

/// Writes [bytes] as `BikeControl <timestamp>.jpg` into [directoryPath] and
/// completes only once the file is on disk; throws if it can't be written.
Future<File> saveScreenshotFile(String directoryPath, List<int> bytes, DateTime now) async {
  final timestamp = now.toIso8601String().split('.').first.replaceAll(':', '-');
  final separator = directoryPath.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator;
  final file = File('$directoryPath${separator}BikeControl $timestamp.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Builds the image from raw screen-capture bytes. Windows (GetDIBits) and
/// macOS deliver BGRA; flutter_screen_capture's own toImage() assumes RGBA on
/// Windows, which swapped red and blue in every Windows screenshot.
image_lib.Image screenshotImage({
  required List<int> bytes,
  required int width,
  required int height,
  required TargetPlatform platform,
}) {
  final bgra = platform == TargetPlatform.windows || platform == TargetPlatform.macOS;
  return image_lib.Image.fromBytes(
    width: width,
    height: height,
    bytes: Uint8List.fromList(bytes).buffer,
    order: bgra ? image_lib.ChannelOrder.bgra : image_lib.ChannelOrder.rgba,
  );
}
