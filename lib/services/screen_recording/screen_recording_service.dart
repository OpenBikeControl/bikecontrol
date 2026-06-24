import 'dart:io';

import 'package:bike_control/services/screen_recording/backends/android_screen_recorder.dart';
import 'package:bike_control/services/screen_recording/backends/native_channel_screen_recorder.dart';
import 'package:bike_control/services/screen_recording/backends/unsupported_screen_recorder.dart';
import 'package:flutter/foundation.dart';

enum ScreenRecordingState { idle, starting, recording, stopping, unsupported, error }

/// Outcome of a [ScreenRecordingService.toggle].
class RecordingResult {
  final bool ok;

  /// True if this toggle *started* recording; false if it *stopped* (or failed).
  final bool startedRecording;

  /// Saved file path when a stop succeeded (desktop surfaces this); null otherwise.
  final String? savedPath;
  final String? errorMessage;

  const RecordingResult({
    required this.ok,
    required this.startedRecording,
    this.savedPath,
    this.errorMessage,
  });
}

/// Platform capture backend. Implementations: Android (package), native channel
/// (iOS/macOS/Windows), and unsupported (web/Linux/too-old OS).
abstract class ScreenRecorderBackend {
  /// Whether this OS build can capture at all.
  Future<bool> isAvailable();

  /// Ensure capture permission, prompting if needed. Returns true if granted.
  Future<bool> ensurePermission();

  /// Begin capture. Returns true if recording started.
  Future<bool> start();

  /// Stop capture and persist. Returns the saved path (may be null on mobile gallery saves).
  Future<String?> stop();
}

/// Owns recording lifecycle/state. All logic lives here so it is unit-testable
/// with a fake backend; the per-platform native work lives in the backends.
class ScreenRecordingService {
  ScreenRecordingService({required ScreenRecorderBackend backend}) : _backend = backend;

  final ScreenRecorderBackend _backend;
  final ValueNotifier<ScreenRecordingState> _state = ValueNotifier(ScreenRecordingState.idle);

  ValueListenable<ScreenRecordingState> get state => _state;
  bool get isRecording => _state.value == ScreenRecordingState.recording;
  Future<bool> get isAvailable => _backend.isAvailable();

  /// Toggle recording. Never throws — failures map to `ok: false`.
  Future<RecordingResult> toggle() async {
    if (isRecording) {
      return _stop();
    }
    return _start();
  }

  Future<RecordingResult> _start() async {
    try {
      if (!await _backend.isAvailable()) {
        _state.value = ScreenRecordingState.unsupported;
        return const RecordingResult(ok: false, startedRecording: false);
      }
      _state.value = ScreenRecordingState.starting;
      if (!await _backend.ensurePermission()) {
        _state.value = ScreenRecordingState.idle;
        return const RecordingResult(ok: false, startedRecording: false, errorMessage: 'permission denied');
      }
      final started = await _backend.start();
      _state.value = started ? ScreenRecordingState.recording : ScreenRecordingState.idle;
      return RecordingResult(ok: started, startedRecording: true);
    } catch (e, s) {
      _state.value = ScreenRecordingState.error;
      debugPrintStack(label: 'screen recording: $e', stackTrace: s);
      return RecordingResult(ok: false, startedRecording: true, errorMessage: e.toString());
    }
  }

  Future<RecordingResult> _stop() async {
    try {
      _state.value = ScreenRecordingState.stopping;
      final path = await _backend.stop();
      _state.value = ScreenRecordingState.idle;
      return RecordingResult(ok: true, startedRecording: false, savedPath: path);
    } catch (e, s) {
      _state.value = ScreenRecordingState.error;
      debugPrintStack(label: 'screen recording: $e', stackTrace: s);
      return RecordingResult(ok: false, startedRecording: false, errorMessage: e.toString());
    }
  }
}

/// Selects the backend for the running platform. Android's real backend is
/// added in a later task; until then Android falls back to unsupported so the
/// app stays buildable.
ScreenRecorderBackend createScreenRecorderBackend() {
  if (kIsWeb) return UnsupportedScreenRecorder();
  if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
    return NativeChannelScreenRecorder();
  }
  if (Platform.isAndroid) return AndroidScreenRecorder();
  return UnsupportedScreenRecorder();
}
