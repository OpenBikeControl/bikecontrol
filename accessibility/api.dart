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
  final int top;
  final int bottom;
  final int right;
  final int left;

  WindowEvent({
    required this.packageName,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
}

@EventChannelApi()
abstract class EventChannelMethods {
  WindowEvent streamEvents();
}
