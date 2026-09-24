import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_sheets.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart';
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/onboarding/steps/step_welcome.dart';
import 'package:bike_control/pages/onboarding/steps/step_where.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const double kOnboardingDesktopBreakpoint = 800;
const double kOnboardingBodyMaxWidth = 640;

String onboardingStepLabel(BuildContext context, OnboardingStep step) => switch (step) {
      OnboardingStep.app => context.i18n.onboardingStepApp,
      OnboardingStep.where => context.i18n.onboardingStepWhere,
      OnboardingStep.controller => context.i18n.onboardingStepController,
      OnboardingStep.virtualShifting => context.i18n.onboardingStepVs,
      OnboardingStep.connection => context.i18n.onboardingStepConnection,
      OnboardingStep.done => context.i18n.onboardingStepDone,
    };

String onboardingStepSub(BuildContext context, OnboardingStep step) => switch (step) {
      OnboardingStep.app => context.i18n.onboardingStepAppSub,
      OnboardingStep.where => context.i18n.onboardingStepWhereSub,
      OnboardingStep.controller => context.i18n.onboardingStepControllerSub,
      OnboardingStep.virtualShifting => context.i18n.onboardingStepVsSub,
      OnboardingStep.connection => context.i18n.onboardingStepConnectionSub,
      OnboardingStep.done => context.i18n.onboardingStepDoneSub,
    };

/// Pure shell — mobile: header + progress bar + body + sticky footer;
/// desktop (>=800): left step rail + centred column + right-aligned footer.
/// Kept as a top-level function so snapshot tests can render any state.
Widget onboardingShell(
  BuildContext context, {
  required OnboardingStep step,
  required Widget body,
  required List<Widget> footerActions,
  VoidCallback? onBack,
  required VoidCallback onHelp,
  VoidCallback? onClose,
  void Function(OnboardingStep)? onSelectStep,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= kOnboardingDesktopBreakpoint;
      final scrolledBody = SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: desktop
            ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kOnboardingBodyMaxWidth), child: body))
            : body,
      );

      if (!desktop) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  if (onBack != null) IconButton.ghost(icon: Icon(LucideIcons.arrowLeft), onPressed: onBack),
                  Image.asset('icon.png', width: 30, height: 30),
                  Expanded(
                    child: Text(
                      context.i18n.onboardingStepOf('${step.index + 1}', '${OnboardingStep.values.length}'),
                      textAlign: TextAlign.center,
                    ).xSmall.semiBold.muted,
                  ),
                  Button.ghost(
                    style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                    onPressed: onHelp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.border),
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context).colorScheme.card,
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.lifeBuoy, size: 14, color: onboardingAccent(context)),
                        Gap(5),
                        Text(context.i18n.onboardingHelp).xSmall.semiBold,
                      ]),
                    ),
                  ),
                  if (onClose != null) IconButton.ghost(icon: Icon(LucideIcons.x), onPressed: onClose),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  for (var i = 0; i < OnboardingStep.values.length; i++) ...[
                    if (i > 0) Gap(4),
                    Expanded(
                      child: Builder(builder: (context) {
                        final bar = AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i <= step.index
                                ? onboardingAccent(context)
                                : Theme.of(context).colorScheme.border,
                          ),
                        );
                        // Completed segments navigate back — a taller hit
                        // target wraps the 4px bar.
                        if (i < step.index && onSelectStep != null) {
                          return Button.ghost(
                            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                            onPressed: () => onSelectStep(OnboardingStep.values[i]),
                            child: SizedBox(height: 24, child: Center(child: bar)),
                          );
                        }
                        return SizedBox(height: 24, child: Center(child: bar));
                      }),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: scrolledBody),
            if (footerActions.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.card,
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < footerActions.length; i++) ...[if (i > 0) Gap(8), footerActions[i]],
                  ],
                ),
              ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 268,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted,
              border: Border(right: BorderSide(color: Theme.of(context).colorScheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Horizontal padding lines the logo up with the step badges
                // below (their tiles carry 12px inner padding).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Image.asset('icon.png', width: 30, height: 30),
                    Gap(10),
                    Text('BikeControl').semiBold,
                  ]),
                ),
                Gap(18),
                for (final s in OnboardingStep.values) _railStep(context, s, step, onSelectStep: onSelectStep),
                const Spacer(),
                Button.ghost(
                  style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                  onPressed: onHelp,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.card,
                      border: Border.all(color: Theme.of(context).colorScheme.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.lifeBuoy, size: 16, color: onboardingAccent(context)),
                      Gap(9),
                      Expanded(child: Text(context.i18n.onboardingHelpAndSupport).small.semiBold),
                      Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (onClose != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 14, 0),
                    child: Row(children: [
                      const Spacer(),
                      IconButton.ghost(icon: Icon(LucideIcons.x), onPressed: onClose),
                    ]),
                  ),
                Expanded(child: scrolledBody),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.card,
                    border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
                  ),
                  child: Row(
                    children: [
                      if (onBack != null) GhostButton(onPressed: onBack, child: Text(context.i18n.onboardingBack)),
                      const Spacer(),
                      for (var i = 0; i < footerActions.length; i++) ...[if (i > 0) Gap(10), footerActions[i]],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Widget _railStep(BuildContext context, OnboardingStep s, OnboardingStep current,
    {void Function(OnboardingStep)? onSelectStep}) {
  final done = s.index < current.index;
  final active = s == current;
  final scheme = Theme.of(context).colorScheme;
  final tile = Container(
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: active ? scheme.card : null,
      border: Border.all(color: active ? scheme.border : const Color(0x00000000)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFF22C55E)
                : active
                    ? onboardingAccent(context)
                    : scheme.border,
          ),
          child: done
              ? Icon(LucideIcons.check, size: 13, color: onboardingOnAccent)
              : DefaultTextStyle.merge(
                  style: TextStyle(color: active ? onboardingOnAccent : scheme.mutedForeground),
                  child: Text('${s.index + 1}').xSmall.semiBold,
                ),
        ),
        Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(onboardingStepLabel(context, s)).small.semiBold,
              Text(onboardingStepSub(context, s)).xSmall.muted,
            ],
          ),
        ),
      ],
    ),
  );
  // Completed steps are re-enterable — the wizard's state is settings-backed,
  // so revisiting is safe and lands with current values pre-selected.
  if (done && onSelectStep != null) {
    return Button.ghost(
      style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
      onPressed: () => onSelectStep(s),
      child: tile,
    );
  }
  return tile;
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingStep _step = OnboardingStep.app;
  SupportedApp? _selectedApp;
  Target? _selectedTarget;

  ControllerPhase _controllerPhase = ControllerPhase.permission;
  // Mobile opens on a welcome screen; the desktop rail already frames the
  // flow, so it starts on step 1. Re-runs from the menu skip it too.
  bool _showWelcome = core.settings.getOnboardingState() != Settings.onboardingStateCompleted;
  // True once the welcome screen has been shown — step 1 then skips its own
  // update banner, so the offer never appears twice.
  bool _showedWelcome = false;

  /// All connection-method singletons the done step's readiness reads —
  /// listened so "Almost there" flips to "You're ready to ride" live.
  late final List<Listenable> _methodListenables = [
    core.obpMdnsEmulator.isConnected,
    core.obpBluetoothEmulator.isConnected,
    core.whooshLink.isConnected,
    core.zwiftEmulator.isConnected,
    core.zwiftMdnsEmulator.isConnected,
    core.rouvyMdnsEmulator.isConnected,
    core.local.isConnected,
    core.remotePairing.isConnected,
    core.remoteKeyboardPairing.isConnected,
  ];
  void _onMethodConnectionChanged() {
    if (mounted) setState(() {});
  }

  /// Context under this page's Scaffold — shadcn's DrawerOverlay (which hosts
  /// openSheet/openDrawer) is created by Scaffold, so the State's own context
  /// sits ABOVE it and cannot open sheets ("No DrawerOverlay found").
  BuildContext? _overlayContext;
  BuildContext get _sheetContext => _overlayContext ?? context;
  Timer? _emptyScanTimer;
  StreamSubscription<BaseDevice>? _connectionSub;
  StreamSubscription<BaseNotification>? _actionSub;
  final Set<String> _setupPrompted = {};
  // The Click V2 explainer covers the whole left/right pair, but the two
  // sides are discovered by separate connectionStream events firing separate
  // concurrent _promptSubFlowsIfNeeded runs — marking uniqueIds is racy (the
  // second side may not exist yet when the first run marks "the pair"). One
  // flag, set synchronously before the await, guarantees a single auto-open;
  // the row's "Setup needed" button is the way back in.
  bool _clickV2AutoPrompted = false;
  // Press-flash state for the controller contour, mirroring OverviewPage's
  // _onButtonPressed: generation bumps re-trigger AnimatedButtonWidget.
  final Map<String, ControllerButton> _pressedButton = {};
  final Map<String, int> _pressGeneration = {};
  final Set<ProxyDevice> _proxyListenerDevices = {};

  bool get _selfHosted => core.settings.getTrainerApp() is BikeControl;

  @override
  void initState() {
    super.initState();
    onboardingActive = true;
    _selectedApp = core.settings.getTrainerApp();
    _selectedTarget = core.settings.getLastTarget();
    _attachProxyListeners();
    for (final l in _methodListenables) {
      l.addListener(_onMethodConnectionChanged);
    }
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (!mounted) return;
      setState(() {
        if (_step == OnboardingStep.controller &&
            (_controllerPhase == ControllerPhase.scanning || _controllerPhase == ControllerPhase.empty) &&
            core.connection.controllerDevices.isNotEmpty) {
          _controllerPhase = ControllerPhase.list;
          _emptyScanTimer?.cancel();
        }
      });
      _attachProxyListeners();
      unawaited(_promptSubFlowsIfNeeded());
    });
    _actionSub = core.connection.actionStream.listen((notification) {
      if (!mounted) return;
      // Presses animate the matching button on the contour (like the home
      // screen's device card) — they no longer advance the wizard.
      if (notification is ButtonNotification && notification.buttonsClicked.isNotEmpty) {
        final id = notification.device.uniqueId;
        _pressGeneration[id] = (_pressGeneration[id] ?? 0) + 1;
        setState(() => _pressedButton[id] = notification.buttonsClicked.first);
      }
    });
  }

  @override
  void dispose() {
    onboardingActive = false;
    for (final l in _methodListenables) {
      l.removeListener(_onMethodConnectionChanged);
    }
    _connectionSub?.cancel();
    _actionSub?.cancel();
    _emptyScanTimer?.cancel();
    for (final proxy in _proxyListenerDevices) {
      proxy.isStarting.removeListener(_onProxyStateChanged);
      proxy.isConnectedListenable.removeListener(_onProxyStateChanged);
    }
    super.dispose();
  }

  /// Attaches a bridging-state listener to every proxy device we haven't
  /// seen yet — called from [initState] for devices already known at
  /// startup, and again from the connectionStream listener as new proxy
  /// devices are discovered, so the step-4 UI updates live as a trainer
  /// starts/stops bridging without needing a full rebuild trigger elsewhere.
  void _attachProxyListeners() {
    for (final proxy in core.connection.proxyDevices) {
      if (_proxyListenerDevices.add(proxy)) {
        proxy.isStarting.addListener(_onProxyStateChanged);
        proxy.isConnectedListenable.addListener(_onProxyStateChanged);
      }
    }
  }

  void _onProxyStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Auto-opens a device's guided sub-flow (Click V2 unlock, SRAM guided
  /// setup) the first time it connects during the controller step. Keyed on
  /// `uniqueId` so a device is only ever prompted once, and so
  /// ZwiftClickV2LeftSide/RightSide (a connected pair) aren't each prompted
  /// separately.
  ///
  /// Opens the device-specific setup sub-flow — used by the one-time
  /// auto-prompt AND the row's "Setup needed" button (the sub-flow can be
  /// cancelled, so it must always be re-openable).
  Future<void> _openSetupFor(BaseDevice d) async {
    try {
      final isClickV2Side = d is ZwiftClickV2 || d is ZwiftClickV2RightSide;
      if (isClickV2Side && ClickV2Onboarding.isPending) {
        await context.push(const ClickV2OnboardingPage());
      } else if (d is SramAxs && d.needsGuidedSetup) {
        await d.showGuidedSetup(_sheetContext);
      }
      if (mounted) setState(() {});
    } catch (e, s) {
      recordError(e, s, context: 'onboarding open device setup');
    }
  }

  Future<void> _promptSubFlowsIfNeeded() async {
    for (final d in core.connection.controllerDevices) {
      if (_setupPrompted.contains(d.uniqueId)) continue;
      if (_step != OnboardingStep.controller) continue;
      final isClickV2Side = d is ZwiftClickV2 || d is ZwiftClickV2RightSide;
      if (isClickV2Side && ClickV2Onboarding.isPending) {
        if (_clickV2AutoPrompted) continue;
        _clickV2AutoPrompted = true;
        await _openSetupFor(d);
      } else if (d.isConnected && d is SramAxs && d.needsGuidedSetup) {
        _setupPrompted.add(d.uniqueId);
        await _openSetupFor(d);
      }
    }
  }

  /// Single place both [_next] and [_back] route transitions through, so any
  /// step-entry side effect (currently just the controller step's permission
  /// check + scan kickoff) fires exactly once, regardless of transition
  /// direction.
  void _goTo(OnboardingStep step) {
    setState(() => _step = step);
    if (step == OnboardingStep.controller) _enterControllerStep();
    if (step == OnboardingStep.connection) _enterConnectionStep();
  }

  /// A network method already switched on is only re-verified here: the toggle
  /// in [setOnboardingMethodEnabled] checks on the way *on*, which a rider who
  /// arrives with it already enabled never crosses.
  Future<void> _enterConnectionStep() async {
    final app = _selectedApp;
    if (app == null) return;
    try {
      await verifyEnabledNetworkMethod(_sheetContext, app, onUpdate: () {
        if (mounted) setState(() {});
      });
    } catch (e, s) {
      recordError(e, s, context: 'onboarding connection step requirements');
    }
  }

  void _next() => _goTo(onboardingNextStep(_step, appIsSelfHosted: _selfHosted));

  /// Back unwinds within the controller step first: from `list`/`empty` it
  /// restarts the scan phase instead of leaving the step entirely. Only from
  /// `permission`/`scanning` does it fall through to the previous step —
  /// loop-safe, since `scanning` isn't one of the phases that restarts.
  void _back() {
    if (_step == OnboardingStep.controller &&
        (_controllerPhase == ControllerPhase.list || _controllerPhase == ControllerPhase.empty)) {
      _startScanPhase();
      return;
    }
    _goTo(onboardingPreviousStep(_step, appIsSelfHosted: _selfHosted));
  }

  Future<void> _enterControllerStep() async {
    try {
      final requirements = await core.permissions.getScanRequirements();
      if (!mounted) return;
      if (requirements.isEmpty) {
        _startScanPhase();
      } else {
        setState(() => _controllerPhase = ControllerPhase.permission);
      }
    } catch (e, s) {
      recordError(e, s, context: 'onboarding controller step requirements');
    }
  }

  void _startScanPhase() {
    setState(() => _controllerPhase =
        core.connection.controllerDevices.isNotEmpty ? ControllerPhase.list : ControllerPhase.scanning);
    core.connection.performScanning();
    _emptyScanTimer?.cancel();
    _emptyScanTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_controllerPhase == ControllerPhase.scanning && core.connection.controllerDevices.isEmpty) {
        setState(() => _controllerPhase = ControllerPhase.empty);
      }
    });
    // Devices that connected before step 3 was entered (scanning runs from
    // app launch) land straight in `list` phase here — prompt their sub-flows
    // now, since the connectionStream listener won't fire for them again.
    if (_controllerPhase == ControllerPhase.list) unawaited(_promptSubFlowsIfNeeded());
  }

  Future<void> _onAllowBluetooth() async {
    try {
      final requirements = await core.permissions.getScanRequirements();
      if (!mounted) return;
      if (requirements.isEmpty) {
        _startScanPhase();
        return;
      }
      await openPermissionSheet(_sheetContext, requirements);
      if (!mounted) return;
      final recheck = await core.permissions.getScanRequirements();
      if (!mounted) return;
      if (recheck.isEmpty) _startScanPhase();
    } catch (e, s) {
      recordError(e, s, context: 'onboarding allow bluetooth');
    }
  }

  Future<void> _onPermissionNotNow() async {
    try {
      final continueAnyway = await openPermissionDeniedSheet(_sheetContext);
      if (!mounted) return;
      if (continueAnyway == true) {
        _next();
      } else if (continueAnyway == false) {
        await _onAllowBluetooth();
      }
    } catch (e, s) {
      recordError(e, s, context: 'onboarding permission not now');
    }
  }

  /// Mirrors the tap sequence in `proxy.dart` exactly: trial gate, saved
  /// retrofit mode, auto-connect flag, fire-and-forget `startProxy()`, then
  /// push the details page. Smart trainers skip the auto-start block and go
  /// straight to the details page, same as `proxy.dart`.
  /// Connects the tapped trainer in place and bridges it as Virtual Shifting
  /// over WiFi — no consent dialog, no details-page detour. Tapping the row
  /// under the step's "Let BikeControl handle Virtual Shifting" pitch IS the
  /// takeover consent, so it's recorded directly. Mirrors the connect branch
  /// of ConnectionCard._onSelect (proxy_device_details/connection_card.dart);
  /// the details page stays reachable from the home screen for mode changes.
  Future<void> _onPickTrainer(ProxyDevice device) async {
    // _sheetContext, not context: the trial gate in connectTrainerFromPicker
    // opens the Go Pro dialog, whose purchase action opens the paywall drawer.
    // The State's own context sits above the Scaffold's DrawerOverlay, so that
    // drawer died on a null check — see the note on [_sheetContext].
    await connectTrainerFromPicker(_sheetContext, device);
    if (mounted) setState(() {});
  }

  /// Same readiness the done body's headline uses: the app is connected
  /// through an enabled method and any bridged trainer has been picked up.
  bool get _doneAllReady =>
      core.logic.connectedTrainerConnections.any((c) => c.isConnected.value) &&
      (!onboardingTrainerBridged(core.connection.proxyDevices) ||
          core.connection.proxyDevices.any((t) => t.isConnectedListenable.value));

  /// "Let {app} handle Virtual Shifting": the rider explicitly opted out, so
  /// tear down every smart-trainer bridge — including ones still connecting —
  /// before moving on. keepInList so going back re-offers them.
  Future<void> _onSkipVirtualShifting() async {
    try {
      for (final t in core.connection.proxyDevices.toList()) {
        if (t.isStarting.value || t.isStartedListenable.value || t.isConnectedListenable.value || t.isConnected) {
          await core.settings.setAutoConnect(t.trainerKey, false);
          await core.connection.disconnect(t, forget: false, persistForget: false, keepInList: true);
        }
      }
    } catch (e, s) {
      recordError(e, s, context: 'onboarding skip virtual shifting');
    }
    if (mounted) _next();
  }

  Widget _body(BuildContext context) => switch (_step) {
        OnboardingStep.app => onboardingAppBody(
            context,
            // Mobile shows it on the welcome screen instead.
            showUpdateBanner: !_showedWelcome,
            selected: _selectedApp,
            onSelect: (a) => setState(() => _selectedApp = a),
          ),
        OnboardingStep.where => onboardingWhereBody(
            context,
            app: _selectedApp!,
            selected: _selectedTarget,
            onSelect: (t) => setState(() => _selectedTarget = t),
          ),
        OnboardingStep.controller => onboardingControllerBody(
            context,
            phase: _controllerPhase,
            devices: core.connection.controllerDevices,
            appName: _selectedApp?.name ?? '',
            pressedButtons: _pressedButton,
            pressGenerations: _pressGeneration,
            onSetupDevice: (d) => unawaited(_openSetupFor(d)),
            onUpdate: () => setState(() {}),
          ),
        OnboardingStep.virtualShifting => onboardingTrainerBody(
            context,
            app: _selectedApp!,
            trainers: core.connection.proxyDevices,
            onPick: _onPickTrainer,
            onRescan: () {
              core.connection.performScanning();
              setState(() {});
            },
            virtualShiftingBlocked: onboardingVirtualShiftingBlocked(_selectedApp!),
          ),
        OnboardingStep.connection => onboardingConnectionBody(
            context,
            app: _selectedApp!,
            // BikeControl (self-hosted) skips the `where` step, so
            // `_selectedTarget` is stale; `applyTrainerAppSelection` already
            // pinned `Target.thisDevice` into settings for that case.
            target: core.settings.getLastTarget() ?? _selectedTarget ?? Target.otherDevice,
            hasTrainer: onboardingTrainerBridged(core.connection.proxyDevices),
            trainerName: core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull?.name,
            onUpdate: () => setState(() {}),
          ),
        OnboardingStep.done => onboardingDoneBody(
            context,
            app: _selectedApp!,
            controllerName: core.connection.controllerDevices.where((d) => d.isConnected).firstOrNull?.name,
            trainerName: core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull?.name,
            // isConnectedListenable mirrors emulator.isConnected — i.e. the
            // trainer app actually holds the virtual trainer, not just "the
            // bridge is running".
            appConnected: core.logic.connectedTrainerConnections.any((c) => c.isConnected.value),
            trainerAppConnected: core.connection.proxyDevices.any((t) => t.isConnectedListenable.value),
            reduceMotion: MediaQuery.of(context).disableAnimations,
            showTestMode: !IAPManager.instance.isPurchased.value,
          ),
      };

  List<Widget> _footer(BuildContext context) => switch (_step) {
        OnboardingStep.app => [
            PrimaryButton(
              onPressed: _selectedApp == null
                  ? null
                  : () async {
                      try {
                        await applyTrainerAppSelection(_selectedApp!);
                      } catch (e, s) {
                        recordError(e, s, context: 'onboarding apply trainer app selection');
                      }
                      // Apps that can only be reached from a second device
                      // leave the `where` step with a single tile — answer it
                      // for the rider instead of making them tap the only
                      // option to move on.
                      final targets = Target.supportedFor(_selectedApp);
                      if (targets.length == 1) _selectedTarget = targets.single;
                      _next();
                    },
              child: Text(_selectedApp == null
                  ? context.i18n.onboardingAppPickToContinue
                  : context.i18n.onboardingAppContinueWith(_selectedApp!.name)),
            ),
          ],
        OnboardingStep.where => [
            PrimaryButton(
              onPressed: _selectedTarget == null
                  ? null
                  : () async {
                      try {
                        await applyTargetSelection(_selectedTarget!);
                      } catch (e, s) {
                        recordError(e, s, context: 'onboarding apply target selection');
                      }
                      _next();
                    },
              child: Text(context.i18n.onboardingContinue),
            ),
          ],
        OnboardingStep.controller => switch (_controllerPhase) {
            ControllerPhase.permission => [
                PrimaryButton(
                  onPressed: _onAllowBluetooth,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.bluetooth, size: 16),
                    Gap(8),
                    Text(context.i18n.onboardingAllowBluetooth),
                  ]),
                ),
                GhostButton(onPressed: _onPermissionNotNow, child: Text(context.i18n.onboardingNotNow)),
              ],
            ControllerPhase.scanning => [
                GhostButton(
                  onPressed: () {
                    _emptyScanTimer?.cancel();
                    setState(() => _controllerPhase = ControllerPhase.empty);
                  },
                  child: Text(context.i18n.onboardingCantFindController),
                ),
              ],
            ControllerPhase.empty => [
                PrimaryButton(onPressed: _startScanPhase, child: Text(context.i18n.onboardingScanAgain)),
                GhostButton(onPressed: _next, child: Text(context.i18n.onboardingSetUpLater)),
              ],
            ControllerPhase.list => [
                if (core.connection.controllerDevices.any((d) => d.isConnected))
                  PrimaryButton(onPressed: _next, child: Text(context.i18n.onboardingContinue))
                else
                  GhostButton(
                    onPressed: () {
                      _emptyScanTimer?.cancel();
                      setState(() => _controllerPhase = ControllerPhase.empty);
                    },
                    child: Text(context.i18n.onboardingCantFindController),
                  ),
              ],
          },
        OnboardingStep.virtualShifting => [
            if (onboardingTrainerBridged(core.connection.proxyDevices))
              PrimaryButton(onPressed: _next, child: Text(context.i18n.onboardingContinue))
            else
              GhostButton(
                  onPressed: _onSkipVirtualShifting,
                  child: Text(context.i18n.onboardingLetAppHandleVs(_selectedApp!.name))),
          ],
        OnboardingStep.connection => [
            PrimaryButton(
              onPressed: core.logic.hasNoConnectionMethod ? null : _next,
              child: Text(context.i18n.onboardingFinishSetup),
            ),
          ],
        OnboardingStep.done => [
            if (!IAPManager.instance.isPurchased.value)
              PrimaryButton(
                onPressed: () async {
                  try {
                    await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
                    core.logic.startEnabledConnectionMethod(userInitiated: true);
                    if (!mounted || !context.mounted) return;
                    // Platform-correct paywall: RevenueCat's hosted sheet on
                    // iOS/Android, the in-app Paywall drawer on desktop. Going
                    // through IAPManager is what picks the right one — opening
                    // the Paywall widget directly showed mobile riders the
                    // desktop fallback with placeholder "about x €" prices.
                    await IAPManager.instance.purchaseFullVersion(_sheetContext);
                    if (mounted) setState(() {});
                  } catch (e, s) {
                    recordError(e, s, context: 'onboarding done see pro options');
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.award, size: 16),
                  Gap(8),
                  Text(context.i18n.onboardingSeeProOptions),
                ]),
              ),
            GhostButton(
              onPressed: () async {
                try {
                  await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
                  // The launch-time start was skipped while the wizard held the
                  // screen; leaving it is when the enabled methods must come up.
                  core.logic.startEnabledConnectionMethod(userInitiated: true);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e, s) {
                  recordError(e, s, context: 'onboarding done start riding');
                }
              },
              child: Text(_doneAllReady ? context.i18n.onboardingDoneStartRiding : context.i18n.onboardingDoneFinishLater),
            ),
          ],
      };

  /// Leaves the wizard from the welcome screen and records it as done, so a
  /// rider who declines isn't asked again on every launch.
  Future<void> _onWelcomeLater() async {
    try {
      await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
      core.logic.startEnabledConnectionMethod(userInitiated: true);
    } catch (e, s) {
      recordError(e, s, context: 'onboarding welcome later');
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Builder(builder: (overlayContext) {
        _overlayContext = overlayContext;
        if (_showWelcome) {
          // Every platform opens on the welcome screen. Desktop used to drop
          // riders straight into step 1's rail, which asked them to pick a
          // trainer app before anything had said what BikeControl does or how
          // long setup takes — the one screen that answers "what am I about to
          // agree to" was the one desktop never saw.
          _showedWelcome = true;
          return OnboardingWelcome(
            onStart: () => setState(() => _showWelcome = false),
            onLater: _onWelcomeLater,
          );
        }
        return _shell(overlayContext);
      }),
    );
  }

  Widget _shell(BuildContext overlayContext) {
    final context = overlayContext;
    return SafeArea(
        child: onboardingShell(
          overlayContext,
          step: _step,
          // Re-keyed per step + controller phase so every screen re-mounts and
          // its contents reveal themselves again. The reveal lives on the
          // children (see onboardingReveal) rather than on one wrapper, so a
          // screen arrives in reading order instead of all at once.
          body: KeyedSubtree(
            key: ValueKey('onboarding-body-$_step-$_controllerPhase'),
            child: _body(overlayContext),
          ),
          footerActions: _footer(overlayContext),
          onBack: _step == OnboardingStep.app || _step == OnboardingStep.done ? null : _back,
          onHelp: () => openOnboardingHelpSheet(overlayContext, _step),
          onClose: () => Navigator.of(context).maybePop(),
          onSelectStep: (s) {
            // Self-hosted apps skip the where step — route the tap onward.
            if (s == OnboardingStep.where && _selfHosted) {
              _goTo(OnboardingStep.app);
            } else {
              _goTo(s);
            }
          },
        ),
    );
  }
}
