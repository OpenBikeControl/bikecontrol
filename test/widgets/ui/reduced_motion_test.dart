// Looping decorations stand still when the rider asked for less motion
// (Android "Remove animations" / iOS Reduce Motion), as the chain card's
// highlight already does.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:bike_control/widgets/ui/wifi_animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  Future<void> pump(WidgetTester tester, Widget child, {required bool reduce}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: Center(child: child),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  final cases = <String, Widget>{
    'unread badge': const PulsingUnreadBadge(),
    'scan animation': const SmoothWifiAnimation(),
  };

  for (final MapEntry(key: name, value: widget) in cases.entries) {
    testWidgets('$name loops normally', (tester) async {
      await pump(tester, widget, reduce: false);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('$name stands still with reduced motion', (tester) async {
      await pump(tester, widget, reduce: true);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
