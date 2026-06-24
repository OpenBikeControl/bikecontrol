import 'dart:io';

import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:gal/gal.dart';

/// Android backend: system-wide MediaProjection capture via flutter_screen_recording,
/// then the resulting mp4 is copied into the device gallery via `gal`.
class AndroidScreenRecorder implements ScreenRecorderBackend {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> ensurePermission() async {
    // MediaProjection consent is requested by startRecordScreen itself.
    // Gallery save needs gallery access on older Androids; request up front.
    try {
      if (await Gal.hasAccess(toAlbum: true)) return true;
      return await Gal.requestAccess(toAlbum: true);
    } catch (e, s) {
      debugPrintStack(label: 'gal access: $e', stackTrace: s);
      return true; // don't block recording if the gallery check itself failed
    }
  }

  @override
  Future<bool> start() async {
    try {
      // Video only — use startRecordScreen (no audio variant).
      final name = 'BikeControl_${DateTime.now().millisecondsSinceEpoch}';
      return await FlutterScreenRecording.startRecordScreen(name);
    } catch (e, s) {
      debugPrintStack(label: 'android startRecordScreen: $e', stackTrace: s);
      return false;
    }
  }

  @override
  Future<String?> stop() async {
    try {
      final path = await FlutterScreenRecording.stopRecordScreen;
      if (path.isEmpty || !File(path).existsSync()) return null;
      await Gal.putVideo(path, album: 'BikeControl');
      return path;
    } catch (e, s) {
      debugPrintStack(label: 'android stopRecordScreen/gal: $e', stackTrace: s);
      return null;
    }
  }
}
