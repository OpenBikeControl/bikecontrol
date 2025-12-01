import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/testbed.dart';
import 'package:swift_control/widgets/ui/button_widget.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/actions/base_actions.dart';
import '../utils/keymap/keymap.dart';

final touchAreaSize = 42.0;

class TouchAreaSetupPage extends StatefulWidget {
  final KeyPair keyPair;
  const TouchAreaSetupPage({super.key, required this.keyPair});

  @override
  State<TouchAreaSetupPage> createState() => _TouchAreaSetupPageState();
}

class _TouchAreaSetupPageState extends State<TouchAreaSetupPage> {
  Uint8List? _backgroundImage;
  final TransformationController _transformationController = TransformationController();

  late Rect _imageRect;

  bool _showFaded = true;

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      final image = File(result.path);
      final Directory tempDir = await getTemporaryDirectory();
      final tempImage = File('${tempDir.path}/${core.actionHandler.supportedApp?.name ?? 'temp'}_screenshot.png');
      await image.copy(tempImage.path);
      _backgroundImage = tempImage.readAsBytesSync();
      await _calculateBounds();
    }
  }

  Future<void> _calculateBounds() async {
    if (_backgroundImage == null) return;

    // need to decode image to get its size so we can have a percentage mapping
    final decodedImage = await decodeImageFromList(_backgroundImage!);
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
    setState(() {});
  }

  void _saveAndClose() {
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    super.dispose();
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
    getTemporaryDirectory().then((tempDir) async {
      final tempImage = File('${tempDir.path}/${core.actionHandler.supportedApp?.name ?? 'temp'}_screenshot.png');
      if (tempImage.existsSync()) {
        _backgroundImage = tempImage.readAsBytesSync();
        setState(() {});

        // wait a bit until device rotation is done
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _calculateBounds();
        });
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
          KeypairExplanation(withKey: true, keyPair: keyPair),
        ],
      ),
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Tooltip(
        message: context.i18n.dragToReposition,
        child: AnimatedOpacity(
          opacity: _showFaded && widget.keyPair != keyPair ? 0.2 : 1.0,
          duration: Duration(milliseconds: 300),
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
              if (keyPair != widget.keyPair && _showFaded) {
                setState(() {
                  _showFaded = false;
                });
              }
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
          final keyPairsToShow =
              core.actionHandler.supportedApp?.keymap.keyPairs
                  .where((kp) => kp.touchPosition != Offset.zero && !kp.isSpecialKey)
                  .toList() ??
              [];
          return InteractiveViewer(
            transformationController: _transformationController,
            child: Stack(
              children: [
                if (_backgroundImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.memory(
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

                for (final keyPair in keyPairsToShow)
                  _buildDraggableArea(
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
                  ),

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
                              context.i18n.touchAreaInstructions,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _pickScreenshot();
                            },
                            child: Text(context.i18n.loadScreenshotForPlacement),
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
                        label: Text(context.i18n.save),
                      ),
                      PopupMenuButton(
                        itemBuilder: (c) => [
                          PopupMenuItem(
                            child: Text(context.i18n.chooseAnotherScreenshot),
                            onTap: () {
                              _pickScreenshot();
                            },
                          ),
                          PopupMenuItem(
                            child: Text(context.i18n.reset),
                            onTap: () {
                              _backgroundImage = null;

                              core.actionHandler.supportedApp?.keymap.reset();
                              setState(() {});
                            },
                          ),
                        ],
                        icon: Icon(Icons.more_vert),
                      ),
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
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (withKey)
          Row(
            children: keyPair.buttons.map((b) => ButtonWidget(button: b, big: true)).toList(),
          )
        else
          Icon(keyPair.icon),
        if (keyPair.inGameAction != null && core.logic.emulatorEnabled && keyPair.touchPosition == Offset.zero)
          _KeyWidget(
            label: [
              keyPair.inGameAction.toString().split('.').last,
              if (keyPair.inGameActionValue != null) ': ${keyPair.inGameActionValue}',
            ].joinToString(separator: ''),
          )
        else if (keyPair.isSpecialKey && core.actionHandler.supportedModes.contains(SupportedMode.media))
          _KeyWidget(
            label: switch (keyPair.physicalKey) {
              PhysicalKeyboardKey.mediaPlayPause => 'Play/Pause',
              PhysicalKeyboardKey.mediaStop => 'Stop',
              PhysicalKeyboardKey.mediaTrackPrevious => 'Previous',
              PhysicalKeyboardKey.mediaTrackNext => 'Next',
              PhysicalKeyboardKey.audioVolumeUp => 'Volume Up',
              PhysicalKeyboardKey.audioVolumeDown => 'Volume Down',
              _ => 'Unknown',
            },
          )
        else if (keyPair.physicalKey != null && core.actionHandler.supportedModes.contains(SupportedMode.keyboard)) ...[
          _KeyWidget(
            label: [
              ...keyPair.modifiers.map((e) => e.name.replaceAll('Modifier', '')),
              keyPair.logicalKey?.keyLabel ?? 'Unknown',
            ].joinToString(separator: '+'),
          ),
          if (keyPair.isLongPress) Text(context.i18n.longPress, style: TextStyle(fontSize: 10)),
        ] else ...[
          if (!withKey && keyPair.touchPosition != Offset.zero)
            _KeyWidget(label: 'X:${keyPair.touchPosition.dx.toInt()}, Y:${keyPair.touchPosition.dy.toInt()}'),
          if (keyPair.isLongPress) Text(context.i18n.longPress, style: TextStyle(fontSize: 10)),
        ],
      ],
    );
  }
}

class _KeyWidget extends StatelessWidget {
  final String label;
  const _KeyWidget({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        constraints: BoxConstraints(minWidth: 30),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label.splitByUpperCase(),
            style: TextStyle(
              fontFamily: screenshotMode ? null : 'monospace',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
