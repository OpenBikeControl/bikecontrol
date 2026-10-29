import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/pages/subscriptions/sync_settings_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.load(const Locale('en'));
  });

  test('device summary counts synced gear profiles next to mappings', () {
    final settings = UserSettings(
      version: 23,
      keymaps: {'MyWhoosh': []},
      shiftingConfigs: [
        ShiftingConfig.defaults(trainerKey: 'Tacx Neo 2T', name: '11-34'),
        ShiftingConfig.defaults(trainerKey: 'Tacx Neo 2T', name: '11-32', isActive: false),
      ],
    );

    expect(syncDeviceSummaryText(l10n, settings), l10n.syncDeviceSummary('23', '1', '2'));
  });

  test('device summary shows zero gear profiles for rows synced before profiles existed', () {
    const settings = UserSettings(version: 6);

    expect(syncDeviceSummaryText(l10n, settings), l10n.syncDeviceSummary('6', '0', '0'));
  });
}
