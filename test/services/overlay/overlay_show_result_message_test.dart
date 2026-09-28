import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.load(const Locale('en')));

  // The failure's `message` is diagnostic detail (often a raw exception, in
  // English); the rider sees a translated sentence chosen by the failure kind.
  test('a failed overlay never shows the raw diagnostic message', () {
    const result = OverlayShowResult.fail(
      OverlayShowFailure.unknown,
      message: 'Failed to open overlay window: PlatformException(boom)',
    );
    expect(result.riderMessage(l10n), isNot(contains('boom')));
    expect(result.riderMessage(l10n), l10n.overlayCouldNotStart);
  });

  test('each failure kind has its own explanation', () {
    final texts = {
      for (final f in OverlayShowFailure.values) OverlayShowResult.fail(f, message: 'x').riderMessage(l10n),
    };
    expect(texts, hasLength(OverlayShowFailure.values.length));
    expect(
      OverlayShowResult.fail(OverlayShowFailure.permissionDenied).riderMessage(l10n),
      l10n.overlayPermissionExplain,
    );
    expect(OverlayShowResult.fail(OverlayShowFailure.systemDisabled).riderMessage(l10n), l10n.overlayLowPowerMode);
  });
}
