import 'dart:ffi' show Abi;

import 'package:bike_control/widgets/menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the support bundle names the active renderer and CPU architecture', () async {
    debugDiagnosticsGatherOverride = ({bool includeDiscovery = true}) => Future.error(StateError('not under test'));
    addTearDown(() => debugDiagnosticsGatherOverride = null);

    final text = await debugText(includeDiscovery: false);

    expect(text, matches(RegExp('^Renderer: (Impeller|Skia) \\(${Abi.current()}\\)\$', multiLine: true)));
  });
}
