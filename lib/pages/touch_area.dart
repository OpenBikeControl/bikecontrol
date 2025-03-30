import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swift_control/main.dart';

final touchAreaSize = 32.0;

class TouchAreaSetupPage extends StatefulWidget {
  final void Function(Offset gearUp, Offset gearDown) onSave;

  const TouchAreaSetupPage({required this.onSave, super.key});

  @override
  State<TouchAreaSetupPage> createState() => _TouchAreaSetupPageState();
}

class _TouchAreaSetupPageState extends State<TouchAreaSetupPage> {
  File? _backgroundImage;
  Offset _gearUpPos = const Offset(200, 300);
  Offset _gearDownPos = const Offset(100, 300);

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _backgroundImage = File(result.path);
      });
    }
  }

  void _saveAndClose() {
    widget.onSave(_gearUpPos, _gearDownPos);
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

      if (actionHandler.gearUpTouchPosition != null) {
        _gearUpPos = actionHandler.gearUpTouchPosition!;
        _gearUpPos = Offset(
          _gearUpPos.dx / devicePixelRatio - touchAreaSize / 2,
          _gearUpPos.dy / devicePixelRatio - touchAreaSize / 2,
        );
      }

      if (actionHandler.gearDownTouchPosition != null) {
        _gearDownPos = actionHandler.gearDownTouchPosition!;
        _gearDownPos = Offset(
          _gearDownPos.dx / devicePixelRatio - touchAreaSize / 2,
          _gearDownPos.dy / devicePixelRatio - touchAreaSize / 2,
        );
      }
      setState(() {});
    });
  }

  Widget _buildDraggableArea({
    required Offset position,
    required void Function(Offset newPosition) onPositionChanged,
    required Color color,
    required String label,
  }) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Draggable(
        feedback: Material(color: Colors.transparent, child: _TouchDot(color: Colors.yellow, label: label)),
        childWhenDragging: const SizedBox.shrink(),
        onDraggableCanceled: (_, offset) {
          setState(() => onPositionChanged(offset));
        },
        child: _TouchDot(color: color, label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_backgroundImage != null)
            Positioned.fill(child: Opacity(opacity: 0.5, child: Image.file(_backgroundImage!, fit: BoxFit.cover)))
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text('''1. Create an in-game screenshot of your app (e.g. within MyWhoosh)
2. Load the screenshot with the button below
3. Make sure the app is in the correct orientation (portrait or landscape)
4. Drag the touch areas to the correct position where the gear up / down buttons are located
5. Save and close this screen'''),
                  ElevatedButton(
                    onPressed: () {
                      _pickScreenshot();
                    },
                    child: Text('Load in-game screenshot for placement'),
                  ),
                ],
              ),
            ),
          // Touch Areas
          _buildDraggableArea(
            position: _gearUpPos,
            onPositionChanged: (newPos) => _gearUpPos = newPos,
            color: Colors.green,
            label: "Gear ↑",
          ),
          _buildDraggableArea(
            position: _gearDownPos,
            onPositionChanged: (newPos) => _gearDownPos = newPos,
            color: Colors.red,
            label: "Gear ↓",
          ),
          Positioned(
            top: 40,
            right: 170,
            child: ElevatedButton.icon(
              onPressed: () {
                _gearDownPos = Offset(100, 300);
                _gearUpPos = Offset(200, 300);
                setState(() {});
              },
              label: const Icon(Icons.lock_reset),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.save),
              label: const Text("Save & Close"),
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchDot extends StatelessWidget {
  final Color color;
  final String label;

  const _TouchDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: touchAreaSize,
          height: touchAreaSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
        ),
        Text(label, style: TextStyle(color: Colors.black, fontSize: 12)),
      ],
    );
  }
}
