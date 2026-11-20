// A controller row's tile: its silhouette when it has one, else the app's one
// controller glyph — two different gamepad icons showed up side by side.
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/controller_mark.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ShadcnApp(
    theme: BkTheme.build(Brightness.light),
    home: Center(child: child),
  ),
);

void main() {
  testWidgets('a controller with a contour shows it, at the tile size', (tester) async {
    final click = ZwiftClickV2LeftSide(BleDevice(name: 'Zwift Click V2', deviceId: 'mark-click'));
    await _pump(tester, ControllerMark(device: click));
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((svg.bytesLoader as SvgAssetLoader).assetName, click.controllerLayout.svgAsset);
    expect(tester.getSize(find.byType(ControllerMark)), const Size.square(BkIconTile.size));
  });

  testWidgets('one without falls back to the one controller glyph', (tester) async {
    final sterzo = EliteSterzo(BleDevice(name: 'STERZO', deviceId: 'mark-sterzo'));
    expect(sterzo.controllerLayout.svgAsset, isNull);
    await _pump(tester, ControllerMark(device: sterzo));
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.widget<BkIconTile>(find.byType(BkIconTile)).icon, LucideIcons.gamepad2);
  });
}
