import 'package:bike_control/services/screen_recording/screen_recording_service.dart';

/// Backend for platforms/OS versions that cannot capture (web, Linux, macOS < 12.3, old Windows).
class UnsupportedScreenRecorder implements ScreenRecorderBackend {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> ensurePermission() async => false;
  @override
  Future<bool> start() async => false;
  @override
  Future<String?> stop() async => null;
}
