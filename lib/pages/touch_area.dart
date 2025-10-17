import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:window_manager/window_manager.dart';

import '../bluetooth/messages/notification.dart';
import '../utils/actions/base_actions.dart';
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
  ControllerButton? _pressedButton;
  final TransformationController _transformationController = TransformationController();

  late Rect _imageRect;

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      final image = File(result.path);

      // need to decode image to get its size so we can have a percentage mapping
      final decodedImage = await decodeImageFromList(image.readAsBytesSync());
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
      _backgroundImage = image;
      setState(() {});
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

    // initialize _imageRect by using Flutter view size
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = flutterView.physicalSize / flutterView.devicePixelRatio;
    _imageRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Force landscape orientation during keymap editing
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(true);
    }
    _actionSubscription = connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification) {
        _pressedButton = data.buttonsClicked.singleOrNull;
      }

      if (_pressedButton != null) {
        if (actionHandler.supportedApp!.keymap.getKeyPair(_pressedButton!) == null) {
          final KeyPair keyPair;
          actionHandler.supportedApp!.keymap.keyPairs.add(
            keyPair = KeyPair(
              touchPosition: Offset((actionHandler.supportedApp!.keymap.keyPairs.length + 1) * 10, 10),
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

  Widget _buildDraggableArea({
    required bool enableTouch,
    required void Function(Offset newPosition) onPositionChanged,
    required Color color,
    required KeyPair keyPair,
  }) {
    // map the percentage position to the image rect
    final relativeX = min(100.0, keyPair.touchPosition.dx) / 100.0;
    final relativeY = min(100.0, keyPair.touchPosition.dy) / 100.0;
    //print('Relative position: $relativeX, $relativeY');
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;

    // figure out notch height for e.g. macOS. On Windows the display size is not available (0,0).
    final differenceInHeight = (flutterView.display.size.height > 0 && !Platform.isIOS)
        ? (flutterView.display.size.height - flutterView.physicalSize.height) / flutterView.devicePixelRatio
        : 0.0;

    // Store the initial drag position to calculate drag distance
    Offset? dragStartPosition;

    if (kDebugMode && false) {
      print('Display Size: ${flutterView.display.size}');
      print('View size: ${flutterView.physicalSize}');
      print('Difference: $differenceInHeight');
    }

    //final isOnTheRightEdge = position.dx > (MediaQuery.sizeOf(context).width - 250);

    final iconSize = 40.0;

    final Offset position = Offset(
      _imageRect.left + relativeX * _imageRect.width - iconSize / 2,
      _imageRect.top + relativeY * _imageRect.height - differenceInHeight - iconSize / 2,
    );

    final actions = [
      if (actionHandler.supportedModes.contains(SupportedMode.keyboard))
        PopupMenuItem<PhysicalKeyboardKey>(
          value: null,
          child: ListTile(
            leading: Icon(Icons.keyboard_alt_outlined),
            title: const Text('Simulate Keyboard shortcut'),
            trailing: keyPair.physicalKey != null ? Checkbox(value: true, onChanged: null) : null,
          ),
          onTap: () async {
            await showDialog<void>(
              context: context,
              barrierDismissible: false, // enable Escape key
              builder: (c) =>
                  HotKeyListenerDialog(customApp: actionHandler.supportedApp! as CustomApp, keyPair: keyPair),
            );
            setState(() {});
          },
        ),
      if (actionHandler.supportedModes.contains(SupportedMode.touch))
        PopupMenuItem<PhysicalKeyboardKey>(
          value: null,
          child: ListTile(
            title: const Text('Simulate Touch'),
            leading: Icon(Icons.touch_app_outlined),
            trailing: keyPair.physicalKey == null && keyPair.touchPosition != Offset.zero
                ? Checkbox(value: true, onChanged: null)
                : null,
          ),
          onTap: () {
            keyPair.physicalKey = null;
            keyPair.logicalKey = null;
            setState(() {});
          },
        ),

      if (actionHandler.supportedModes.contains(SupportedMode.media))
        PopupMenuItem<PhysicalKeyboardKey>(
          child: PopupMenuButton<PhysicalKeyboardKey>(
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (keyPair.isSpecialKey) Checkbox(value: true, onChanged: null),
                  Icon(Icons.arrow_right),
                ],
              ),
              title: Text('Simulate Media key'),
            ),
          ),
        ),
    ];

    final icon = Container(
      constraints: BoxConstraints(minHeight: iconSize, minWidth: iconSize),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (keyPair.buttons.singleOrNull?.color == null)
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              width: iconSize,
              height: iconSize,
              child: Icon(
                keyPair.icon,
                size: iconSize - 12,
                shadows: [
                  Shadow(color: Colors.white, offset: Offset(1, 1)),
                  Shadow(color: Colors.white, offset: Offset(-1, -1)),
                  Shadow(color: Colors.white, offset: Offset(-1, 1)),
                  Shadow(color: Colors.white, offset: Offset(-1, 1)),
                  Shadow(color: Colors.white, offset: Offset(1, -1)),
                ],
              ),
            ),
          PopupMenuButton<PhysicalKeyboardKey>(
            enabled: enableTouch,
            itemBuilder: (context) => [
              if (actions.length > 1) ...actions,
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
              PopupMenuItem<PhysicalKeyboardKey>(
                value: null,
                child: ListTile(
                  title: const Text('Delete Keymap'),
                  leading: Icon(Icons.delete, color: Colors.red),
                ),
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
            child: Row(
              children: [
                KeypairExplanation(withKey: true, keyPair: keyPair),
                Icon(Icons.more_vert),
              ],
            ),
          ),
        ],
      ),
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Tooltip(
        message: 'Drag to reposition',
        child: Draggable(
          dragAnchorStrategy: (widget, context, position) {
            final scale = _transformationController.value.getMaxScaleOnAxis();
            final RenderBox renderObject = context.findRenderObject() as RenderBox;
            return renderObject.globalToLocal(position).scale(scale, scale);
          },
          feedback: Material(
            color: Colors.transparent,
            child: icon,
          ),
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () {
            // Capture the starting position to calculate drag distance later
            dragStartPosition = position;
          },
          onDragEnd: (details) {
            // Calculate drag distance to prevent accidental repositioning from clicks
            // while allowing legitimate drags even with low velocity (e.g., when overlapping buttons)
            final dragDistance = dragStartPosition != null
                ? (details.offset - dragStartPosition!).distance
                : double.infinity;

            // Only update position if dragged more than 5 pixels (prevents accidental clicks)
            if (dragDistance > 5) {
              final matrix = Matrix4.inverted(_transformationController.value);
              final height = 0;
              final sceneY = details.offset.dy - height;
              final viewportPoint = MatrixUtils.transformPoint(
                matrix,
                Offset(details.offset.dx, sceneY) + Offset(iconSize / 2, differenceInHeight + iconSize / 2),
              );
              setState(() => onPositionChanged(viewportPoint));
            }
          },
          child: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_backgroundImage == null && constraints.biggest != _imageRect.size) {
            _imageRect = Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
          }
          return InteractiveViewer(
            transformationController: _transformationController,
            child: Stack(
              children: [
                if (_backgroundImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.file(
                        _backgroundImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                // draw _imageRect for debugging
                if (kDebugMode)
                  Positioned(
                    left: _imageRect.left,
                    top: _imageRect.top,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: SizedBox.fromSize(size: _imageRect.size),
                    ),
                  ),

                ...?actionHandler.supportedApp?.keymap.keyPairs.map((keyPair) {
                  return _buildDraggableArea(
                    enableTouch: true,
                    keyPair: keyPair,
                    onPositionChanged: (newPos) {
                      // convert to percentage
                      final relativeX = ((newPos.dx - _imageRect.left) / _imageRect.width).clamp(0.0, 1.0);
                      final relativeY = ((newPos.dy - _imageRect.top) / _imageRect.height).clamp(0.0, 1.0);
                      keyPair.touchPosition = Offset(relativeX * 100.0, relativeY * 100.0);
                      setState(() {});
                    },
                    color: Colors.red,
                  );
                }),

                Positioned.fill(child: Testbed()),

                if (_backgroundImage == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          IgnorePointer(
                            child: Text(
                              '''1. Create an in-game screenshot of your app (e.g. within MyWhoosh) in landscape orientation
2. Load the screenshot with the button below
3. The app is automatically set to landscape orientation for accurate mapping
4. Press a button on your Click device to create a touch area
5. Drag the touch areas to the desired position on the screenshot
6. Save and close this screen''',
                            ),
                          ),
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

                Positioned(
                  top: 40,
                  right: 20,
                  child: Row(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveAndClose,
                        icon: const Icon(Icons.save),
                        label: const Text("Save"),
                      ),
                      PopupMenuButton(
                        itemBuilder: (c) => [
                          PopupMenuItem(
                            child: Text('Reset'),
                            onTap: () {
                              _backgroundImage = null;
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
        },
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
        if (withKey)
          Row(
            children: keyPair.buttons.map((b) => ButtonWidget(button: b, big: true)).toList(),
          )
        else
          Icon(keyPair.icon),
        if (keyPair.physicalKey != null && actionHandler.supportedModes.contains(SupportedMode.keyboard)) ...[
          KeyWidget(
            label: switch (keyPair.physicalKey) {
              PhysicalKeyboardKey.mediaPlayPause => 'Play/Pause',
              PhysicalKeyboardKey.mediaStop => 'Stop',
              PhysicalKeyboardKey.mediaTrackPrevious => 'Previous',
              PhysicalKeyboardKey.mediaTrackNext => 'Next',
              PhysicalKeyboardKey.audioVolumeUp => 'Volume Up',
              PhysicalKeyboardKey.audioVolumeDown => 'Volume Down',
              _ => keyPair.logicalKey?.keyLabel ?? 'Unknown',
            },
          ),
          if (keyPair.isLongPress) Text('long\npress', style: TextStyle(fontSize: 10)),
        ] else ...[
          if (!withKey)
            KeyWidget(label: 'X: ${keyPair.touchPosition.dx.toInt()}, Y: ${keyPair.touchPosition.dy.toInt()}'),
          if (keyPair.isLongPress) Text('long\npress', style: TextStyle(fontSize: 10)),
        ],
      ],
    );
  }
}
