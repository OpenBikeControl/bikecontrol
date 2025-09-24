import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/widgets/accessibility_disclosure_dialog.dart';

void main() {
  group('AccessibilityDisclosureDialog', () {
    testWidgets('shows proper consent options with two buttons', (WidgetTester tester) async {
      bool acceptCalled = false;
      bool denyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibilityDisclosureDialog(
              onAccept: () => acceptCalled = true,
              onDeny: () => denyCalled = true,
            ),
          ),
        ),
      );

      // Verify dialog shows proper title
      expect(find.text('Accessibility Service Permission Required'), findsOneWidget);
      
      // Verify both consent options are present
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);

      // Verify explanation text is present
      expect(find.textContaining('AccessibilityService API'), findsOneWidget);
      expect(find.textContaining('simulate touch gestures'), findsOneWidget);
      expect(find.textContaining('No personal data'), findsOneWidget);

      // Test deny button
      await tester.tap(find.text('Deny'));
      await tester.pump();
      expect(denyCalled, isTrue);

      // Reset and test accept button
      denyCalled = false;
      await tester.tap(find.text('Allow'));
      await tester.pump();
      expect(acceptCalled, isTrue);
    });

    testWidgets('includes required disclosure information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibilityDisclosureDialog(
              onAccept: () {},
              onDeny: () {},
            ),
          ),
        ),
      );

      // Check for key disclosure elements required by Play Store
      expect(find.textContaining('Why is this permission needed?'), findsOneWidget);
      expect(find.textContaining('How does SwiftControl use this permission?'), findsOneWidget);
      expect(find.textContaining('Zwift Click, Zwift Ride, or Zwift Play'), findsOneWidget);
      expect(find.textContaining('training app window is active'), findsOneWidget);
    });
  });
}