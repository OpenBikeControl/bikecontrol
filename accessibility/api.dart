import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class Accessibility {
  bool hasPermission();

  void openPermissions();

  void performTouch(double x, double y, {bool isKeyDown = true, bool isKeyUp = false});

  void controlMedia(MediaAction action);

  bool isRunning();

  void ignoreHidDevices();
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

class AKeyEvent {
  final String source;
  final String hidKey;
  final bool keyDown;
  final bool keyUp;

  AKeyEvent({required this.source, required this.hidKey, required this.keyDown, required this.keyUp});
}

@EventChannelApi()
abstract class EventChannelMethods {
  WindowEvent streamEvents();
  AKeyEvent hidKeyPressed();
}
