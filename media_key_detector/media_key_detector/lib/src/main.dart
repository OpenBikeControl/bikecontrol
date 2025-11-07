import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

MediaKeyDetectorPlatform get _platform => MediaKeyDetectorPlatform.instance;

/// Returns the name of the current platform.
Future<String> getPlatformName() async {
  final platformName = await _platform.getPlatformName();
  if (platformName == null) throw Exception('Unable to get platform name.');
  return platformName;
}
