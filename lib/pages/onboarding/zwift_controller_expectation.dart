import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';

/// Which expectation note a Zwift-made controller gets for the selected app.
enum ZwiftExpectationVariant {
  /// The app is Zwift itself, which reads the controller natively.
  zwift,

  /// An officially supported app: shifting and the main controls work.
  officialApp,

  /// The app's keymap exposes a handful of actions; they are listed.
  appActions,

  /// An OpenBikeControl-compatible app reports its own controls.
  appDefined,

  /// A custom app without a preset: the rider picks what each button does.
  customApp,

  /// The app reads no button input at all.
  noInput,
}

class ZwiftControllerExpectation {
  const ZwiftControllerExpectation({
    required this.variant,
    required this.device,
    required this.app,
    this.actions = const [],
  });

  final ZwiftExpectationVariant variant;

  /// The Zwift-made controller the note is about.
  final BaseDevice device;
  final SupportedApp app;

  /// Only for [ZwiftExpectationVariant.appActions].
  final List<InGameAction> actions;

  /// The note's copy. [deviceName] is the device's display name, which needs
  /// a BuildContext and so is resolved by the caller.
  String text(AppLocalizations l, {required String deviceName}) => switch (variant) {
    ZwiftExpectationVariant.zwift => l.onboardingZwiftNoteZwift(deviceName),
    ZwiftExpectationVariant.officialApp => l.onboardingZwiftNoteOfficial(deviceName, app.name),
    ZwiftExpectationVariant.appActions => l.onboardingZwiftNoteActions(
      deviceName,
      app.name,
      actions.map((a) => a.title).join(', '),
    ),
    ZwiftExpectationVariant.appDefined => l.onboardingZwiftNoteAppDefined(deviceName, app.name),
    ZwiftExpectationVariant.customApp => l.onboardingZwiftNoteCustom(deviceName, app.name),
    ZwiftExpectationVariant.noInput => l.onboardingZwiftNoteNoInput(deviceName, app.name),
  };
}

/// The in-app actions BikeControl can trigger in [app] out of the box: the
/// distinct actions of its preset key pairs (a pair without an explicit action
/// uses its button's default), renamed through the app's
/// [SupportedApp.inGameActionsMapping]. Actions BikeControl handles itself
/// (trainer, headwind, …) are not the app's and are left out.
List<InGameAction> triggerableActions(SupportedApp app) {
  final result = <InGameAction>[];
  for (final pair in [...app.keymap.keyPairs, ...app.additionalKeyPairs]) {
    final raw = pair.inGameAction ?? (pair.buttons.isEmpty ? null : pair.buttons.first.action);
    if (raw == null) continue;
    final action = app.inGameActionsMapping[raw] ?? raw;
    if (action.isOutsideTrainerApp || result.contains(action)) continue;
    result.add(action);
  }
  return result;
}

/// Decides whether (and which) expectation note the onboarding controller
/// list shows. Null when no trainer app is picked, no Zwift-made controller
/// is in [devices], or the rider rides in BikeControl itself.
ZwiftControllerExpectation? zwiftControllerExpectation({
  required List<BaseDevice> devices,
  required SupportedApp? app,
}) {
  if (app == null || app is BikeControl) return null;
  final zwiftDevices = devices.whereType<ZwiftDevice>();
  if (zwiftDevices.isEmpty) return null;
  final device = zwiftDevices.where((d) => d.isConnected).firstOrNull ?? zwiftDevices.first;

  ZwiftControllerExpectation of(ZwiftExpectationVariant v, [List<InGameAction> actions = const []]) =>
      ZwiftControllerExpectation(variant: v, device: device, app: app, actions: actions);

  if (app is Zwift) return of(ZwiftExpectationVariant.zwift);
  if (app.officialIntegration) return of(ZwiftExpectationVariant.officialApp);
  if (!app.receivesButtonEvents) return of(ZwiftExpectationVariant.noInput);
  final actions = triggerableActions(app);
  if (actions.isNotEmpty) return of(ZwiftExpectationVariant.appActions, actions);
  final speaksObc = app.connections.any(
    (c) =>
        c.$1 == AppConnectionMethod.obpBle ||
        c.$1 == AppConnectionMethod.obpMdns ||
        c.$1 == AppConnectionMethod.obpDirCon,
  );
  if (speaksObc) return of(ZwiftExpectationVariant.appDefined);
  return of(ZwiftExpectationVariant.customApp);
}
