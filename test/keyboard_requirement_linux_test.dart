import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  tearDown(() => debugHostPlatformOverride = null);

  test('Linux explains /dev/uinput access instead of a settings screen', () {
    debugHostPlatformOverride = TargetPlatform.linux;
    final message = KeyboardRequirement.accessMessage();
    expect(message, isNot(AppLocalizations.current.enableKeyboardAccessMessage));
    expect(message, contains('/dev/uinput'));
  });

  test('macOS keeps the settings-screen message', () {
    debugHostPlatformOverride = TargetPlatform.macOS;
    expect(KeyboardRequirement.accessMessage(), AppLocalizations.current.enableKeyboardAccessMessage);
  });
}
