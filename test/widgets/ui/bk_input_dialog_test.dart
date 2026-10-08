// Text-input dialogs keep a phone dialog's width: on a desktop window they
// must not stretch the field across the whole screen.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What a dialog that asks for text may be wide, at most.
const maxInputDialogWidth = 420.0;

void main() {
  testWidgets('a text-input dialog on a 1280-wide window stays narrow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Builder(
          builder: (context) => Center(
            child: Button.primary(
              onPressed: () => KeymapManager().showNewProfileDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = tester.getSize(find.byType(AlertDialog));
    expect(dialog.width, lessThanOrEqualTo(maxInputDialogWidth));
    // Still a usable field, not collapsed to its hint.
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(200));
  });
}
