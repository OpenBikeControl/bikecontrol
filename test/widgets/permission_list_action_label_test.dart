// A requirement can name its own action ("Open Bluetooth settings") instead
// of the generic "Grant", and an informational one (a PC without a Bluetooth
// adapter) must not keep the permission sheet from finishing.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/permissions_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class _Requirement extends PlatformRequirement {
  _Requirement({this.label, this.informational = false}) : super('Requirement', icon: Icons.bluetooth);

  final String? label;
  final bool informational;
  int calls = 0;

  @override
  String? get actionLabel => label;

  @override
  bool get isInformational => informational;

  @override
  Future<bool> getStatus() async => status;

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    calls++;
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(child: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the requirement\'s own action label instead of Grant', (tester) async {
    final requirement = _Requirement(label: 'Do the thing');
    await _pump(tester, PermissionList(requirements: [requirement], onDone: () {}));

    expect(find.text('Do the thing'), findsOneWidget);
  });

  testWidgets('falls back to Grant without one', (tester) async {
    final withLabel = _Requirement(label: 'Do the thing');
    await _pump(tester, PermissionList(requirements: [withLabel], onDone: () {}));
    final grantWithLabel = find.text(AppLocalizations.current.grant).evaluate().length;

    await _pump(tester, PermissionList(requirements: [_Requirement()], onDone: () {}));
    expect(find.text(AppLocalizations.current.grant).evaluate().length, grantWithLabel + 1);
  });

  testWidgets('an informational requirement does not keep the sheet open', (tester) async {
    final informational = _Requirement(label: 'Do the thing', informational: true);
    var done = 0;
    await _pump(tester, PermissionList(requirements: [informational], onDone: () => done++));

    await tester.tap(find.text('Do the thing'));
    await tester.pumpAndSettle();

    expect(informational.calls, 1);
    expect(done, 1);
  });
}
