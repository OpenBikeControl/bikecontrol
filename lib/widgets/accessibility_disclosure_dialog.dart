import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';

class AccessibilityDisclosureDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const AccessibilityDisclosureDialog({
    super.key,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accessibility Service Permission Required'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SwiftControl needs to use Android\'s AccessibilityService API to function properly.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Why is this permission needed?'),
            SizedBox(height: 8),
            Text('• To simulate touch gestures on your screen for controlling trainer apps'),
            Text('• To detect which training app window is currently active'),
            Text('• To enable you to control apps like MyWhoosh, IndieVelo, and others using your Zwift devices'),
            SizedBox(height: 16),
            Text(
              'How does SwiftControl use this permission?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• When you press buttons on your Zwift Click, Zwift Ride, or Zwift Play devices, SwiftControl simulates touch gestures at specific screen locations'),
            Text('• The app monitors which training app window is active to ensure gestures are sent to the correct app'),
            Text('• No personal data is accessed or collected through this service'),
            SizedBox(height: 16),
            Text(
              'SwiftControl will only access your screen to perform the gestures you configure. No other accessibility features or personal information will be accessed.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDeny,
          child: const Text('Deny'),
        ),
        ElevatedButton(
          onPressed: onAccept,
          child: const Text('Allow'),
        ),
      ],
    );
  }
}