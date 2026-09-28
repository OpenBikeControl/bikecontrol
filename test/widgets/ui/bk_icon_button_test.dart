import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    ShadcnApp(theme: BkTheme.build(Brightness.light), home: Center(child: child)),
  );

  testWidgets('announces its label as a button and taps through', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, BkIconButton.ghost(icon: const Icon(LucideIcons.arrowLeft), label: 'Back', onPressed: () => taps++));

    expect(
      find.semantics.byLabel('Back'),
      containsSemantics(isButton: true, isEnabled: true, hasEnabledState: true, hasTapAction: true, isFocusable: true),
    );
    tester.semantics.tap(find.semantics.byLabel('Back'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a disabled button says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const BkIconButton.primary(icon: Icon(LucideIcons.send), label: 'Send message', onPressed: null));
    expect(
      find.semantics.byLabel('Send message'),
      containsSemantics(isButton: true, isEnabled: false, hasEnabledState: true, hasTapAction: false),
    );
    handle.dispose();
  });

  testWidgets('meets the labelled tap-target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, BkIconButton.ghost(icon: const Icon(LucideIcons.x), label: 'Close', onPressed: () {}));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    // flutter_test reports Android, so ShadcnApp's mobile scaling applies.
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('shows the label as a tooltip on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester, BkIconButton.ghost(icon: const Icon(LucideIcons.x), label: 'Close', onPressed: () {}));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(BkIconButton)));
      expect(find.byType(Tooltip), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Close'), findsOneWidget);
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
