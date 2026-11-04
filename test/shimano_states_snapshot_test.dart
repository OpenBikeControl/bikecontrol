@Tags(['screenshots'])
library;

import 'package:bike_control/bluetooth/devices/shimano/shimano_setup_sheet.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show ShimanoShifter;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

/// Renders every Shimano Di2 setup state to a PNG for UX review.
///
/// Output: `build/snapshots/di2_*-<locale>.png` (light) and `di2_*_dark-<locale>.png`.
/// Run: `flutter test --run-skipped test/shimano_states_snapshot_test.dart`
///
/// Each sheet stage is rendered through [shimanoGuidedBody] /
/// [shimanoModeChoiceBody], the builders the live sheets use.
Future<void> main() async {
  await ensureSnapshotHarness();

  const locales = ['en'];

  Widget sheet(Widget body) => Card(
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: body),
      );

  Widget panel(
    BuildContext c, {
    bool buttonMode = false,
    bool channels = false,
    bool canRestore = false,
    bool warning = false,
  }) =>
      Card(
        child: shimanoSetupPanel(
          c,
          buttonMode: buttonMode,
          channels: channels,
          canRestore: canRestore,
          showButtonModeWarning: warning,
          onSetup: () {},
          onRestore: () {},
          onTurnOff: () {},
          onSwitchToChannels: () {},
          onDismissWarning: () {},
        ),
      );

  Widget channelsBody(BuildContext c, ShimanoSetupStage stage, {Set<ShimanoShifter>? seen, int runningStep = 0}) =>
      sheet(shimanoGuidedBody(
        c,
        stage: stage,
        confirmIcon: LucideIcons.radio,
        title: c.i18n.shimanoChannelsTitle,
        intro: c.i18n.shimanoChannelsIntro,
        successMessage: c.i18n.shimanoChannelsSuccess,
        runningTitle: c.i18n.shimanoSettingUp,
        successTitle: c.i18n.shimanoAllSet,
        checklistItems: [
          c.i18n.shimanoChecklistAuthenticating,
          c.i18n.shimanoChecklistReadingButtons,
          c.i18n.shimanoChecklistAssigning,
        ],
        passkeyField: const SizedBox(),
        onClose: () {},
        onProceed: () {},
        shiftersSeen: seen,
        afterChooser: true,
        runningStep: runningStep,
        checklistAutoAdvance: false,
      ));

  Widget restoreBody(BuildContext c, ShimanoSetupStage stage, {Set<ShimanoShifter>? seen}) => sheet(shimanoGuidedBody(
        c,
        stage: stage,
        confirmIcon: LucideIcons.rotateCcw,
        title: c.i18n.shimanoRestore,
        intro: c.i18n.shimanoRestoreIntro,
        successMessage: c.i18n.shimanoRestoreSuccess,
        runningTitle: c.i18n.shimanoRestoring,
        successTitle: c.i18n.shimanoRestoredTitle,
        checklistItems: [c.i18n.shimanoChecklistAuthenticating, c.i18n.shimanoChecklistRestoring],
        passkeyField: const SizedBox(),
        onClose: () {},
        onProceed: () {},
        shiftersSeen: seen,
        checklistAutoAdvance: false,
      ));

  Widget buttonsBody(BuildContext c, ShimanoSetupStage stage) => sheet(shimanoGuidedBody(
        c,
        stage: stage,
        confirmIcon: LucideIcons.gamepad2,
        title: c.i18n.shimanoSetup,
        intro: c.i18n.shimanoSetupIntro,
        successMessage: c.i18n.shimanoSetupSuccess,
        runningTitle: c.i18n.shimanoSettingUp,
        successTitle: c.i18n.shimanoAllSet,
        checklistItems: [c.i18n.shimanoChecklistAuthenticating, c.i18n.shimanoChecklistActivating],
        passkeyField: const SizedBox(),
        onClose: () {},
        onProceed: () {},
        afterChooser: true,
        checklistAutoAdvance: false,
      ));

  final shots = <String, (double, bool, Widget Function(BuildContext))>{
    'di2_01_panel_not_set_up': (380, true, (c) => panel(c)),
    'di2_02_choose_mode': (440, true, (c) => sheet(shimanoModeChoiceBody(
          c,
          selected: ShimanoSetupMode.channels,
          onSelect: (_) {},
          onClose: () {},
          onContinue: () {},
        ))),
    'di2_03_channels_confirm': (440, true, (c) => channelsBody(c, ShimanoSetupStage.confirm)),
    'di2_04_channels_authenticating': (440, false, (c) => channelsBody(c, ShimanoSetupStage.running)),
    'di2_05_channels_press_shifters': (440, true, (c) => channelsBody(c, ShimanoSetupStage.running, seen: {})),
    'di2_06_channels_press_right': (
      440,
      true,
      (c) => channelsBody(c, ShimanoSetupStage.running, seen: {ShimanoShifter.left}),
    ),
    'di2_07_channels_writing': (440, false, (c) => channelsBody(c, ShimanoSetupStage.running, runningStep: 2)),
    'di2_08_channels_success': (440, true, (c) => channelsBody(c, ShimanoSetupStage.success)),
    'di2_09_panel_channels_active': (380, true, (c) => panel(c, channels: true, canRestore: true)),
    'di2_10_restore_confirm': (440, true, (c) => restoreBody(c, ShimanoSetupStage.confirm)),
    'di2_11_restore_press_shifters': (440, true, (c) => restoreBody(c, ShimanoSetupStage.running, seen: {})),
    'di2_12_restore_success': (440, true, (c) => restoreBody(c, ShimanoSetupStage.success)),
    'di2_13_buttons_confirm': (440, true, (c) => buttonsBody(c, ShimanoSetupStage.confirm)),
    'di2_14_panel_button_mode_warning': (380, true, (c) => panel(c, buttonMode: true, warning: true)),
    'di2_15_panel_button_mode': (380, true, (c) => panel(c, buttonMode: true)),
    'di2_16_panel_dfly_from_etube': (380, true, (c) => panel(c, channels: true)),
    'di2_17_wake_your_di2': (440, false, (c) => channelsBody(c, ShimanoSetupStage.authorize)),
  };

  for (final MapEntry(key: name, value: (width, settle, builder)) in shots.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('$name ${brightness.name}', (tester) async {
        await captureWidget(
          tester,
          name: brightness == Brightness.dark ? '${name}_dark' : name,
          width: width,
          locales: locales,
          brightness: brightness,
          settle: settle,
          builder: builder,
        );
      });
    }
  }
}
