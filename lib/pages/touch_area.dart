import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:window_manager/window_manager.dart';

import '../bluetooth/messages/click_notification.dart';
import '../bluetooth/messages/notification.dart';
import '../bluetooth/messages/play_notification.dart';
import '../bluetooth/messages/ride_notification.dart';
import '../utils/keymap/apps/custom_app.dart';
import '../utils/keymap/buttons.dart';
import '../utils/keymap/keymap.dart';
import '../widgets/custom_keymap_selector.dart';

final touchAreaSize = 42.0;

class TouchAreaSetupPage extends StatefulWidget {
  const TouchAreaSetupPage({super.key});

  @override
  State<TouchAreaSetupPage> createState() => _TouchAreaSetupPageState();
}

class _TouchAreaSetupPageState extends State<TouchAreaSetupPage> {
  File? _backgroundImage;
  late StreamSubscription<BaseNotification> _actionSubscription;
  ZwiftButton? _pressedButton;

  Rect? _imageRect;

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _backgroundImage = File(result.path);

        // need to decode image to get its size so we can have a percentage mapping
        if (actionHandler is RemoteActions) {
          decodeImageFromList(_backgroundImage!.readAsBytesSync()).then((decodedImage) {
            print(decodedImage.width);
            print(decodedImage.height);

            // calculate image rectangle in the current screen, given it's boxfit contain
            final screenSize = MediaQuery.sizeOf(context);
            final imageAspectRatio = decodedImage.width / decodedImage.height;
            final screenAspectRatio = screenSize.width / screenSize.height;
            if (imageAspectRatio > screenAspectRatio) {
              // image is wider than screen
              final width = screenSize.width;
              final height = width / imageAspectRatio;
              final top = (screenSize.height - height) / 2;
              _imageRect = Rect.fromLTWH(0, top, width, height);
            } else {
              // image is taller than screen
              final height = screenSize.height;
              final width = height * imageAspectRatio;
              final left = (screenSize.width - width) / 2;
              _imageRect = Rect.fromLTWH(left, 0, width, height);
            }
            print('Image Rect: $_imageRect');
          });
        }
      });
    }
  }

  void _saveAndClose() {
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    super.dispose();
    _actionSubscription.cancel();
    // Exit full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    // Reset orientation preferences to allow all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(false);
    }
  }

  @override
  void initState() {
    super.initState();

    // Force landscape orientation during keymap editing
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []).then((_) {
      // this will make sure the buttons are placed correctly after the transition
      setState(() {});
    });
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(true);
    }
    _actionSubscription = connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ClickNotification) {
        _pressedButton = data.buttonsClicked.singleOrNull;
      }
      if (data is PlayNotification) {
        _pressedButton = data.buttonsClicked.singleOrNull;
      }
      if (data is RideNotification) {
        _pressedButton = data.buttonsClicked.singleOrNull;
      }

      if (_pressedButton != null) {
        if (actionHandler.supportedApp!.keymap.getKeyPair(_pressedButton!) == null) {
          final KeyPair keyPair;
          actionHandler.supportedApp!.keymap.keyPairs.add(
            keyPair = KeyPair(
              touchPosition:
                  _imageRect != null
                      ? Offset(actionHandler.supportedApp!.keymap.keyPairs.length * 10, 10)
                      : context.size!
                          .center(Offset.zero)
                          .translate(actionHandler.supportedApp!.keymap.keyPairs.length * 40, 0),
              buttons: [_pressedButton!],
              physicalKey: null,
              logicalKey: null,
              isLongPress: false,
            ),
          );
          setState(() {});

          // open menu
          if (Platform.isMacOS || Platform.isWindows) {
            await Future.delayed(Duration(milliseconds: 300));
            await keyPressSimulator.simulateMouseClickDown(keyPair.touchPosition);
            await keyPressSimulator.simulateMouseClickUp(keyPair.touchPosition);
          }
        }
      }
    });
  }

  List<Widget> _buildDraggableArea({
    required Offset position,
    required bool enableTouch,
    required void Function(Offset newPosition) onPositionChanged,
    required Color color,
    required KeyPair keyPair,
  }) {
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;

    // figure out notch height for e.g. macOS. On Windows the display size is not available (0,0).
    final differenceInHeight =
        (flutterView.display.size.height > 0 && !Platform.isIOS)
            ? (flutterView.display.size.height - flutterView.physicalSize.height) / flutterView.devicePixelRatio
            : 0.0;

    if (kDebugMode && false) {
      print('Position: $position');
      print('Display Size: ${flutterView.display.size}');
      print('View size: ${flutterView.physicalSize}');
      print('Difference: $differenceInHeight');
    }

    final isOnTheRightEdge = position.dx > (MediaQuery.sizeOf(context).width - 250);
    final label = KeypairExplanation(withKey: true, keyPair: keyPair);

    final iconSize = 40.0;
    final icon = Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        (!keyPair.isSpecialKey && keyPair.physicalKey == null && keyPair.touchPosition != Offset.zero)
            ? Icons.add
            : Icons.drag_indicator_outlined,
        size: iconSize,
        shadows: [
          Shadow(color: Colors.white, offset: Offset(1, 1)),
          Shadow(color: Colors.white, offset: Offset(-1, -1)),
          Shadow(color: Colors.white, offset: Offset(-1, 1)),
          Shadow(color: Colors.white, offset: Offset(-1, 1)),
          Shadow(color: Colors.white, offset: Offset(1, -1)),
        ],
      ),
    );

    return [
      Positioned(
        left: position.dx,
        top: position.dy - differenceInHeight,
        child: FractionalTranslation(
          translation: Offset(isOnTheRightEdge ? -1.0 : 0.0, 0),
          child: PopupMenuButton<PhysicalKeyboardKey>(
            enabled: enableTouch,
            tooltip: 'Drag to reposition. Tap to edit.',
            itemBuilder:
                (context) => [
                  PopupMenuItem<PhysicalKeyboardKey>(
                    value: null,
                    child: ListTile(
                      leading: Icon(Icons.keyboard_alt_outlined),
                      title: const Text('Simulate Keyboard shortcut'),
                    ),
                    onTap: () async {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false, // enable Escape key
                        builder:
                            (c) => HotKeyListenerDialog(
                              customApp: actionHandler.supportedApp! as CustomApp,
                              keyPair: keyPair,
                            ),
                      );
                      setState(() {});
                    },
                  ),
                  PopupMenuItem<PhysicalKeyboardKey>(
                    value: null,
                    child: ListTile(title: const Text('Simulate Touch'), leading: Icon(Icons.touch_app_outlined)),
                    onTap: () {
                      keyPair.physicalKey = null;
                      keyPair.logicalKey = null;
                      setState(() {});
                    },
                  ),
                  PopupMenuItem<PhysicalKeyboardKey>(
                    value: null,
                    onTap: () {
                      keyPair.isLongPress = !keyPair.isLongPress;
                      setState(() {});
                    },
                    child: CheckboxListTile(
                      value: keyPair.isLongPress,
                      onChanged: (value) {
                        keyPair.isLongPress = value ?? false;
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      title: const Text('Long Press Mode (vs. repeating)'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    child: PopupMenuButton<PhysicalKeyboardKey>(
                      padding: EdgeInsets.zero,
                      itemBuilder:
                          (context) => [
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.mediaPlayPause,
                              child: const Text('Media: Play/Pause'),
                            ),
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.mediaStop,
                              child: const Text('Media: Stop'),
                            ),
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.mediaTrackPrevious,
                              child: const Text('Media: Previous'),
                            ),
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.mediaTrackNext,
                              child: const Text('Media: Next'),
                            ),
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.audioVolumeUp,
                              child: const Text('Media: Volume Up'),
                            ),
                            PopupMenuItem<PhysicalKeyboardKey>(
                              value: PhysicalKeyboardKey.audioVolumeDown,
                              child: const Text('Media: Volume Down'),
                            ),
                          ],
                      onSelected: (key) {
                        keyPair.physicalKey = key;
                        keyPair.logicalKey = null;

                        setState(() {});
                      },
                      child: ListTile(
                        leading: Icon(Icons.music_note_outlined),
                        trailing: Icon(Icons.arrow_right),
                        title: Text('Simulate Media key'),
                      ),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<PhysicalKeyboardKey>(
                    value: null,
                    child: ListTile(title: const Text('Delete Keymap'), leading: Icon(Icons.delete, color: Colors.red)),
                    onTap: () {
                      actionHandler.supportedApp!.keymap.keyPairs.remove(keyPair);
                      setState(() {});
                    },
                  ),
                ],
            onSelected: (key) {
              keyPair.physicalKey = key;
              keyPair.logicalKey = null;
              setState(() {});
            },
            child: label,
          ),
        ),
      ),

      Positioned(
        left: position.dx - iconSize / 2,
        top: position.dy - differenceInHeight - iconSize / 2,
        child: Draggable(
          feedback: Material(color: Colors.transparent, child: icon),
          childWhenDragging: const SizedBox.shrink(),
          onDraggableCanceled: (velo, offset) {
            // otherwise simulated touch will move it
            if (velo.pixelsPerSecond.distance > 0) {
              final fixedPosition = offset + Offset(iconSize / 2, differenceInHeight + iconSize / 2);
              setState(() => onPositionChanged(fixedPosition));
            }
          },
          child: icon,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final devicePixelRatio = isDesktop ? 1.0 : MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      body: Stack(
        children: [
          if (_backgroundImage != null)
            Positioned.fill(child: Opacity(opacity: 0.5, child: Image.file(_backgroundImage!, fit: BoxFit.contain)))
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Text('''1. Create an in-game screenshot of your app (e.g. within MyWhoosh) in landscape orientation
2. Load the screenshot with the button below
3. The app is automatically set to landscape orientation for accurate mapping
4. Press a button on your Click device to create a touch area
5. Drag the touch areas to the desired position on the screenshot
6. Save and close this screen'''),
                    ElevatedButton(
                      onPressed: () {
                        _pickScreenshot();
                      },
                      child: Text('Load in-game screenshot for placement'),
                    ),
                  ],
                ),
              ),
            ),
          // draw image rect for debugging
          if (_imageRect != null && _backgroundImage != null)
            Positioned.fromRect(
              rect: _imageRect!,
              child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 2))),
            ),

          if (actionHandler is! RemoteActions || _imageRect != null)
            ...?actionHandler.supportedApp?.keymap.keyPairs.map((keyPair) {
              final Offset offset;

              if (_imageRect != null) {
                // map the percentage position to the image rect
                final relativeX = min(100.0, keyPair.touchPosition.dx) / 100.0;
                final relativeY = min(100.0, keyPair.touchPosition.dy) / 100.0;
                //print('Relative position: $relativeX, $relativeY');
                offset = Offset(
                  _imageRect!.left + relativeX * _imageRect!.width,
                  _imageRect!.top + relativeY * _imageRect!.height,
                );
              } else {
                offset = Offset(
                  keyPair.touchPosition.dx / devicePixelRatio,
                  keyPair.touchPosition.dy / devicePixelRatio,
                );
              }

              //print('Drawing at offset $offset for keypair with position ${keyPair.touchPosition}');

              return _buildDraggableArea(
                enableTouch: true,
                position: offset,
                keyPair: keyPair,
                onPositionChanged: (newPos) {
                  if (_imageRect != null) {
                    // convert to percentage
                    final relativeX = ((newPos.dx - _imageRect!.left) / _imageRect!.width).clamp(0.0, 1.0);
                    final relativeY = ((newPos.dy - _imageRect!.top) / _imageRect!.height).clamp(0.0, 1.0);
                    keyPair.touchPosition = Offset(relativeX * 100.0, relativeY * 100.0);
                  } else {
                    final converted = newPos * devicePixelRatio;
                    keyPair.touchPosition = converted;
                  }
                  setState(() {});
                },
                color: Colors.red,
              );
            }).flatten(),

          Positioned.fill(child: Testbed()),

          Positioned(
            top: 40,
            right: 20,
            child: Row(
              spacing: 8,
              children: [
                ElevatedButton.icon(onPressed: _saveAndClose, icon: const Icon(Icons.save), label: const Text("Save")),
                PopupMenuButton(
                  itemBuilder:
                      (c) => [
                        PopupMenuItem(
                          child: Text('Reset'),
                          onTap: () {
                            actionHandler.supportedApp?.keymap.reset();
                            setState(() {});
                          },
                        ),
                      ],
                  icon: Icon(Icons.more_vert),
                ),
                if (kDebugMode) MenuButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KeypairExplanation extends StatelessWidget {
  final bool withKey;
  final KeyPair keyPair;

  const KeypairExplanation({super.key, required this.keyPair, this.withKey = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (withKey) KeyWidget(label: keyPair.buttons.joinToString(transform: (e) => e.name, separator: '\n')),
        if (keyPair.physicalKey != null) ...[
          Icon(switch (keyPair.physicalKey) {
            PhysicalKeyboardKey.mediaPlayPause ||
            PhysicalKeyboardKey.mediaStop ||
            PhysicalKeyboardKey.mediaTrackPrevious ||
            PhysicalKeyboardKey.mediaTrackNext ||
            PhysicalKeyboardKey.audioVolumeUp ||
            PhysicalKeyboardKey.audioVolumeDown => Icons.music_note_outlined,
            _ => Icons.keyboard,
          }, size: 16),
          KeyWidget(
            label: switch (keyPair.physicalKey) {
              PhysicalKeyboardKey.mediaPlayPause => 'Media: Play/Pause',
              PhysicalKeyboardKey.mediaStop => 'Media: Stop',
              PhysicalKeyboardKey.mediaTrackPrevious => 'Media: Previous',
              PhysicalKeyboardKey.mediaTrackNext => 'Media: Next',
              PhysicalKeyboardKey.audioVolumeUp => 'Media: Volume Up',
              PhysicalKeyboardKey.audioVolumeDown => 'Media: Volume Down',
              _ => keyPair.logicalKey?.keyLabel ?? 'Unknown',
            },
          ),
          if (keyPair.isLongPress) Text('using long press'),
        ] else ...[
          Icon(Icons.touch_app, size: 16),
          KeyWidget(label: 'X: ${keyPair.touchPosition.dx.toInt()}, Y: ${keyPair.touchPosition.dy.toInt()}'),

          if (keyPair.isLongPress) Text('using long press'),
        ],
      ],
    );
  }
}
