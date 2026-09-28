import 'package:flutter/semantics.dart';
import 'package:bike_control/main.dart' show navigatorKey;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// A toast is visual only; without an announcement a screen-reader user never
// hears "Not connected" or "Saved".
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        navigatorKey: navigatorKey,
        theme: BkTheme.build(Brightness.light),
        home: const ToastLayer(child: SizedBox.expand()),
      ),
    );
  }

  testWidgets('a toast announces its title and subtitle', (tester) async {
    await pump(tester);
    buildToast(title: 'Not connected', subtitle: 'Open the trainer app first');
    await tester.pump();
    final announcements = tester.takeAnnouncements();
    expect(announcements, hasLength(1));
    expect(announcements.single.message, 'Not connected. Open the trainer app first');
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('errors are announced assertively', (tester) async {
    await pump(tester);
    buildToast(level: LogLevel.LOGLEVEL_ERROR, title: 'Failed to send');
    await tester.pump();
    final announcements = tester.takeAnnouncements();
    expect(announcements.single.message, 'Failed to send');
    expect(announcements.single.assertiveness, Assertiveness.assertive);
    await tester.pump(const Duration(seconds: 10));
  });
}
