// A guide screenshot that can't load leaves no trace: Shorebird patches ship
// code only, so a newly bundled screenshot is missing on a patched build.
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Size> pumpShot(WidgetTester tester, String source) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: GuideScreenshot(source)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    return tester.getSize(find.byType(GuideScreenshot));
  }

  testWidgets('a missing asset takes no space', (tester) async {
    expect(await pumpShot(tester, 'assets/guides/not-in-this-build.jpg'), Size.zero);
  });

  testWidgets('a bundled asset shows, with its gap', (tester) async {
    final size = await pumpShot(tester, 'assets/guides/mywhoosh-bc2-2-pair-bikecontrol.jpg');
    expect(size.height, greaterThan(8));
  });
}
