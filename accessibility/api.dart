import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class Accessibility {
  bool hasPermission();

  void openPermissions();

  void performTouch(double x, double y);

  void controlMedia(MediaAction action);
}

enum MediaAction { playPause, next, volumeUp, volumeDown }

class WindowEvent {
  final String packageName;
  final int windowHeight;
  final int windowWidth;

  WindowEvent({required this.packageName, required this.windowHeight, required this.windowWidth});
}

@EventChannelApi()
abstract class EventChannelMethods {
  WindowEvent streamEvents();
}
