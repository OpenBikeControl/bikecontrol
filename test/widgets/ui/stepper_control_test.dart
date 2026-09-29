import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('StepperControl renders value label and + / - buttons', (tester) async {
    double current = 10.0;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: StatefulBuilder(
            builder: (context, setState) => StepperControl(
              value: current,
              step: 0.5,
              min: 5.0,
              max: 20.0,
              format: (v) => '${v.toStringAsFixed(1)} kg',
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      ),
    );

    expect(find.text('10.0 kg'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stepper-plus')));
    await tester.pumpAndSettle();
    expect(find.text('10.5 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stepper-minus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stepper-minus')));
    await tester.pumpAndSettle();
    expect(find.text('9.5 kg'), findsOneWidget);
  });

  testWidgets('StepperControl buttons are labelled for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: StepperControl(value: 5, step: 1, min: 5, max: 20, format: (v) => '$v', onChanged: (_) {}),
        ),
      ),
    );
    expect(find.semantics.byLabel('Decrease'), isSemantics(isButton: true, isEnabled: false));
    expect(find.semantics.byLabel('Increase'), isSemantics(isButton: true, isEnabled: true, hasTapAction: true));
    handle.dispose();
  });
}
