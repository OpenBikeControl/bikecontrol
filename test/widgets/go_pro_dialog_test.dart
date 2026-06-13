import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  testWidgets('dialog survives rebuild after its opener is removed from the tree', (tester) async {
    final showOpener = ValueNotifier(true);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: ValueListenableBuilder(
            valueListenable: showOpener,
            builder: (context, visible, _) => visible ? const _Opener() : const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Go Pro'), findsOneWidget);

    // The widget that opened the dialog gets unmounted while the dialog is
    // still showing (e.g. ConnectionCard remounting on device reconnect).
    showOpener.value = false;
    await tester.pump();
    expect(find.text('Go Pro'), findsOneWidget);

    // Any rebuild of the dialog's LoadingWidget (in production: setState when
    // the Go Pro button is tapped) re-runs renderChild, which must not touch
    // the opener's now-defunct context.
    tester.element(find.byType(LoadingWidget)).markNeedsBuild();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Go Pro'), findsOneWidget);
  });
}

class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    return Button.primary(
      onPressed: () => showGoProDialog(context),
      child: const Text('open'),
    );
  }
}
