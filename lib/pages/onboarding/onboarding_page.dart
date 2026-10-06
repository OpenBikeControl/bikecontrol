import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show ControllerPress;
import 'package:bike_control/pages/onboarding/onboarding_network_precheck.dart';
import 'package:bike_control/services/network_self_test/network_check.dart' show NetworkFixId;
import 'package:bike_control/services/network_self_test/network_fixes.dart' show runNetworkFix;
import 'package:bike_control/services/network_self_test/network_method_target.dart' show currentNetworkMethodTarget;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
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
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/widgets/keymap/trainer_app_keymap_prompt.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const double kOnboardingDesktopBreakpoint = Breakpoints.twoPane;
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

/// Pure shell — mobile: "Step N of 6" header with Help, a segmented progress
/// bar, the step's eyebrow, body and the list of steps, then a full-width pill
/// with Back under it; desktop (>=800): a step rail (grouped list) beside a
/// centred column and a right-aligned footer.
/// Kept as a top-level function so snapshot tests can render any state.
///
/// [stepValues] is what a finished step settled on ("MyWhoosh", "This
/// device"), shown at the end of its row in the list of steps.
Widget onboardingShell(
  BuildContext context, {
  required OnboardingStep step,
  required Widget body,
  required List<Widget> footerActions,
  VoidCallback? onBack,
  required VoidCallback onHelp,
  VoidCallback? onClose,
  void Function(OnboardingStep)? onSelectStep,
  Map<OnboardingStep, String> stepValues = const {},
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= kOnboardingDesktopBreakpoint;
      final cs = Theme.of(context).colorScheme;
      // The done step is its own summary: no list of steps.
      final inProgress = step != OnboardingStep.done;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (!desktop && inProgress && step != OnboardingStep.app) ...[
            const Gap(16),
            onboardingStepList(context, current: step, values: stepValues, onSelectStep: onSelectStep),
          ],
        ],
      );
      final scrolledBody = SingleChildScrollView(
        // Keyed per step: the next step starts at the top, not wherever the
        // last one was scrolled to.
        key: ValueKey('onboarding-scroll-$step'),
        padding: EdgeInsets.fromLTRB(desktop ? 24 : 16, 8, desktop ? 24 : 16, 16),
        child: desktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kOnboardingBodyMaxWidth),
                  child: content,
                ),
              )
            : content,
      );

      if (!desktop) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: onClose == null
                        ? null
                        : BkIconButton.ghost(icon: Icon(LucideIcons.x), label: context.i18n.close, onPressed: onClose),
                  ),
                  Expanded(
                    // Read as "Step 3 of 6, Controller: Find and connect" —
                    // the step's name lives in the rail on wide windows and
                    // only here on the phone.
                    child: Semantics(
                      label:
                          '${context.i18n.onboardingStepOf('${step.index + 1}', '${OnboardingStep.values.length}')}, '
                          '${onboardingStepLabel(context, step)}: ${onboardingStepSub(context, step)}',
                      excludeSemantics: true,
                      child: Text(
                        context.i18n.onboardingStepOf('${step.index + 1}', '${OnboardingStep.values.length}'),
                        textAlign: TextAlign.center,
                        style: context.typography.small.copyWith(
                          color: cs.mutedForeground,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: BkIconButton.ghost(
                      icon: Icon(LucideIcons.circleHelp, color: bkAccentText(context)),
                      label: context.i18n.onboardingHelp,
                      onPressed: onHelp,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _progressBar(context, step, onSelectStep),
            ),
            Expanded(child: scrolledBody),
            if (footerActions.isNotEmpty || onBack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _PillFooter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < footerActions.length; i++) ...[
                        if (i > 0) const Gap(4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: BkPillButton.minHeight),
                          child: footerActions[i],
                        ),
                      ],
                      if (onBack != null) ...[
                        const Gap(4),
                        BkTouchTarget(
                          child: GhostButton(
                            alignment: Alignment.center,
                            onPressed: onBack,
                            child: Text(context.i18n.onboardingBack),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            color: bkSunkenSurface(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('icon.png', width: 28, height: 28),
                      Gap(10),
                      Text('BikeControl', style: context.typography.base.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Gap(20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    context.i18n.onboardingStepOf('${step.index + 1}', '${OnboardingStep.values.length}'),
                    style: context.typography.small.copyWith(color: cs.mutedForeground, fontWeight: FontWeight.w500),
                  ),
                ),
                _progressBar(context, step, onSelectStep),
                Gap(12),
                onboardingStepList(
                  context,
                  current: step,
                  values: stepValues,
                  onSelectStep: onSelectStep,
                  showSubtitles: true,
                ),
                const Spacer(),
                BkGroupedSection(
                  children: [
                    BkGroupedRow(
                      icon: LucideIcons.circleHelp,
                      title: context.i18n.onboardingHelpAndSupport,
                      chevron: true,
                      onPressed: onHelp,
                    ),
                  ],
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
                    child: Row(
                      children: [
                        const Spacer(),
                        BkIconButton.ghost(icon: Icon(LucideIcons.x), label: context.i18n.close, onPressed: onClose),
                      ],
                    ),
                  ),
                Expanded(child: scrolledBody),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kOnboardingBodyMaxWidth),
                      child: _PillFooter(
                        child: Row(
                          children: [
                            if (onBack != null)
                              BkTouchTarget(
                                child: GhostButton(
                                  alignment: Alignment.center,
                                  onPressed: onBack,
                                  child: Text(context.i18n.onboardingBack),
                                ),
                              ),
                            const Spacer(),
                            for (var i = 0; i < footerActions.length; i++) ...[
                              if (i > 0) Gap(10),
                              BkTouchTarget(child: footerActions[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
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

/// Six segments, filled in the accent up to the current step. Finished
/// segments take you back to their step.
Widget _progressBar(BuildContext context, OnboardingStep step, void Function(OnboardingStep)? onSelectStep) {
  final cs = Theme.of(context).colorScheme;
  final motion = prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 250);
  return Row(
    children: [
      for (var i = 0; i < OnboardingStep.values.length; i++) ...[
        if (i > 0) const Gap(4),
        Expanded(
          child: Builder(
            builder: (context) {
              final bar = AnimatedContainer(
                key: ValueKey('onboarding-progress-$i'),
                duration: motion,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i <= step.index ? onboardingAccent(context) : cs.border,
                ),
              );
              // Completed segments navigate back — a taller hit target wraps
              // the 4px bar.
              if (i < step.index && onSelectStep != null) {
                return Button.ghost(
                  style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                  onPressed: () => onSelectStep(OnboardingStep.values[i]),
                  child: SizedBox(height: 24, child: Center(child: bar)),
                );
              }
              return SizedBox(height: 24, child: Center(child: bar));
            },
          ),
        ),
      ],
    ],
  );
}

/// The wizard's steps as a grouped list: a green tick for a finished step
/// (with what it settled on at the end), the step's number otherwise, the
/// current one in the accent. Finished steps are re-enterable — the
/// wizard's state is settings-backed, so revisiting is safe and lands with
/// current values pre-selected.
Widget onboardingStepList(
  BuildContext context, {
  required OnboardingStep current,
  Map<OnboardingStep, String> values = const {},
  void Function(OnboardingStep)? onSelectStep,
  bool showSubtitles = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final status = BkStatusColors.of(context);
  final steps = OnboardingStep.values;
  final rows = <Widget>[];
  for (final s in steps) {
    final done = s.index < current.index;
    final active = s == current;
    final value = done ? values[s] : null;
    final tile = SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? status.success
              : active
              ? onboardingAccent(context)
              : cs.muted,
        ),
        child: Center(
          child: done
              ? Icon(LucideIcons.check, size: 14, color: status.successForeground)
              : Text(
                  '${s.index + 1}',
                  style: context.typography.xSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active ? onboardingOnAccent(context) : cs.mutedForeground,
                  ),
                ),
        ),
      ),
    );
    rows.add(
      BkGroupedRow(
        key: ValueKey('onboarding-step-row-${s.name}'),
        leading: tile,
        title: onboardingStepLabel(context, s),
        subtitle: showSubtitles || (!done && !active) ? onboardingStepSub(context, s) : null,
        titleColor: active ? cs.foreground : (done ? cs.foreground : cs.mutedForeground),
        trailing: value == null ? null : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: done && onSelectStep != null ? () => onSelectStep(s) : null,
      ),
    );
  }
  return BkGroupedSection(dividerIndent: BkGroupedSection.inset + 24 + BkGroupedRow.gap, children: rows);
}

/// Rounds the footer's primary buttons into full-width pills and colours its
/// ghost buttons (Back, "Set up later") as accent text.
class _PillFooter extends StatelessWidget {
  const _PillFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(999));
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    final accent = bkAccentText(context);
    return ComponentTheme<PrimaryButtonTheme>(
      data: PrimaryButtonTheme(
        decoration: (context, states, value) => value is BoxDecoration ? value.copyWith(borderRadius: pill) : value,
        padding: (context, states, value) => padding,
        textStyle: (context, states, value) => value.copyWith(fontWeight: FontWeight.w600),
      ),
      child: ComponentTheme<GhostButtonTheme>(
        data: GhostButtonTheme(
          decoration: (context, states, value) => value is BoxDecoration ? value.copyWith(borderRadius: pill) : value,
          textStyle: (context, states, value) => states.contains(WidgetState.disabled)
              ? value
              : value.copyWith(color: accent, fontWeight: FontWeight.w600),
        ),
        child: child,
      ),
    );
  }
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
  // The same presses as notifiers, for the controller card's "Just pressed"
  // strip (shared with Ride's).
  final Map<String, ValueNotifier<ControllerPress>> _presses = {};
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
        final notifier = _presses.putIfAbsent(id, () => ValueNotifier((button: null, generation: 0)));
        notifier.value = (button: notification.buttonsClicked.first, generation: _pressGeneration[id]!);
      }
    });
  }

  @override
  void dispose() {
    _precheckGate
      ..removeListener(_onPrecheckChanged)
      ..dispose();
    onboardingActive = false;
    for (final l in _methodListenables) {
      l.removeListener(_onMethodConnectionChanged);
    }
    _connectionSub?.cancel();
    _actionSub?.cancel();
    for (final notifier in _presses.values) {
      notifier.dispose();
    }
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
    _syncNetworkPrecheck();
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
      await verifyEnabledNetworkMethod(
        _sheetContext,
        app,
        onUpdate: () {
          if (mounted) setState(() {});
        },
      );
    } catch (e, s) {
      recordError(e, s, context: 'onboarding connection step requirements');
    }
  }

  /// The connection step's background network check, for the network
  /// method that is on (see [OnboardingNetworkPrecheckGate]). Stopped when
  /// the step is left or the method switched off.
  late final OnboardingNetworkPrecheckGate _precheckGate = OnboardingNetworkPrecheckGate()
    ..addListener(_onPrecheckChanged);

  void _syncNetworkPrecheck() {
    final wanted = _step == OnboardingStep.connection && !kIsWeb && core.logic.hasNetworkMethodEnabled;
    _precheckGate.sync(wanted: wanted, target: wanted ? currentNetworkMethodTarget() : null);
  }

  void _onPrecheckChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runPrecheckFix(NetworkFixId fix) async {
    try {
      await runNetworkFix(context, fix);
    } catch (e, s) {
      recordError(e, s, context: 'onboarding network precheck fix');
    }
    if (mounted) unawaited(_precheckGate.precheck?.run());
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
    setState(
      () => _controllerPhase = core.connection.controllerDevices.isNotEmpty
          ? ControllerPhase.list
          : ControllerPhase.scanning,
    );
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
  OnboardingDoneState get _doneState => onboardingDoneState(
    hasController: core.connection.controllerDevices.any((d) => d.isConnected),
    appConnected: core.logic.connectedTrainerConnections.any((c) => c.isConnected.value),
    hasTrainer: onboardingTrainerBridged(core.connection.proxyDevices),
    trainerAppConnected: core.connection.proxyDevices.any((t) => t.isConnectedListenable.value),
  );

  bool get _doneOffersOverlay {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    final app = _selectedApp;
    if (trainer == null || app == null) return false;
    return onboardingDoneOffersOverlay(
      app: app,
      trainerBridged: true,
      trainerAppConnected: trainer.isConnectedListenable.value,
      overlayOffered: trainerOverlayOffered(trainer),
      overlayEnabled: core.settings.getOverlayEnabled(),
      overlayDeclined: core.settings.getOverlayDeclined(),
    );
  }

  /// Shows the gear overlay through the app's one enable path, which asks for
  /// Android's draw-over permission first and only records the overlay as on
  /// when something is actually on screen.
  Future<void> _onShowOverlay() async {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    if (trainer == null) return;
    try {
      final result = await enableTrainerOverlay(trainer);
      if (!mounted) return;
      if (!result.ok) {
        buildToast(level: LogLevel.LOGLEVEL_WARNING, title: result.riderMessage(context.i18n));
      }
      setState(() {});
    } catch (e, s) {
      recordError(e, s, context: 'onboarding done show overlay');
    }
  }

  /// The bridged trainer's resistance self-test lives on its details page,
  /// right under the connection card.
  Future<void> _onRunTrainerCheck() async {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    if (trainer == null) return;
    try {
      await context.push(ProxyDeviceDetailsPage(device: trainer, revealSelfTest: true));
      if (mounted) setState(() {});
    } catch (e, s) {
      recordError(e, s, context: 'onboarding done run trainer check');
    }
  }

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
      trainerApp: _selectedApp,
      pressedButtons: _pressedButton,
      pressGenerations: _pressGeneration,
      presses: _presses,
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
      onUpdate: () {
        setState(() {});
        _syncNetworkPrecheck();
      },
      networkStatus: switch (_precheckGate.precheck) {
        null => null,
        final precheck => OnboardingNetworkPrecheckCard(
          precheck: precheck,
          appName: _selectedApp!.name,
          onFix: _runPrecheckFix,
          trainerAppConnected: _precheckGate.trainerAppConnected,
        ),
      },
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
      reduceMotion: prefersReducedMotion(context),
      showTestMode: !IAPManager.instance.isPurchased.value,
      onPairController: () => _goTo(OnboardingStep.controller),
      onRunTrainerCheck: _onRunTrainerCheck,
      waitingOnNetworkMethod: core.logic.hasNetworkMethodEnabled,
      onTestNetwork: () => context.push(const NetworkTroubleshootingPage()),
      offerOverlay: _doneOffersOverlay,
      onShowOverlay: _onShowOverlay,
    ),
  };

  List<Widget> _footer(BuildContext context) => switch (_step) {
    OnboardingStep.app => [
      PrimaryButton(
        alignment: Alignment.center,
        onPressed: _selectedApp == null
            ? null
            : () async {
                // The rider's own mapping made for another app: ask before
                // replacing it (or keeping it) for this one.
                final keymapChoice = await askKeymapForTrainerApp(context, _selectedApp!);
                if (keymapChoice == null || !mounted) return;
                try {
                  await applyTrainerAppSelection(_selectedApp!, keymapChoice: keymapChoice);
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
        child: Text(
          _selectedApp == null
              ? context.i18n.onboardingAppPickToContinue
              : context.i18n.onboardingAppContinueWith(_selectedApp!.name),
        ),
      ),
    ],
    OnboardingStep.where => [
      PrimaryButton(
        alignment: Alignment.center,
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
          alignment: Alignment.center,
          onPressed: _onAllowBluetooth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bluetooth, size: 16),
              Gap(8),
              Text(context.i18n.onboardingAllowBluetooth),
            ],
          ),
        ),
        GhostButton(
          alignment: Alignment.center,
          onPressed: _onPermissionNotNow,
          child: Text(context.i18n.onboardingNotNow),
        ),
      ],
      ControllerPhase.scanning => [
        GhostButton(
          alignment: Alignment.center,
          onPressed: () {
            _emptyScanTimer?.cancel();
            setState(() => _controllerPhase = ControllerPhase.empty);
          },
          child: Text(context.i18n.onboardingCantFindController),
        ),
      ],
      ControllerPhase.empty => [
        PrimaryButton(
          alignment: Alignment.center,
          onPressed: _startScanPhase,
          child: Text(context.i18n.onboardingScanAgain),
        ),
        GhostButton(alignment: Alignment.center, onPressed: _next, child: Text(context.i18n.onboardingSetUpLater)),
      ],
      ControllerPhase.list => [
        if (core.connection.controllerDevices.any((d) => d.isConnected))
          PrimaryButton(alignment: Alignment.center, onPressed: _next, child: Text(context.i18n.onboardingContinue))
        else
          GhostButton(
            alignment: Alignment.center,
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
        PrimaryButton(alignment: Alignment.center, onPressed: _next, child: Text(context.i18n.onboardingContinue))
      else
        GhostButton(
          alignment: Alignment.center,
          onPressed: _onSkipVirtualShifting,
          child: Text(context.i18n.onboardingLetAppHandleVs(_selectedApp!.name)),
        ),
    ],
    OnboardingStep.connection => [
      PrimaryButton(
        alignment: Alignment.center,
        onPressed:
            onboardingConnectionCanFinish(
              hasNoConnectionMethod: core.logic.hasNoConnectionMethod,
              networkBlocking: _precheckGate.blocking,
            )
            ? _next
            : null,
        child: Text(context.i18n.onboardingFinishSetup),
      ),
    ],
    OnboardingStep.done => onboardingDoneFooter(
      context,
      state: _doneState,
      showPlanOptions: !IAPManager.instance.isPurchased.value,
      onStartRiding: () async {
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
      onSeePlanOptions: () async {
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
    ),
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
      child: Builder(
        builder: (overlayContext) {
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
        },
      ),
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
        stepValues: {
          if (_selectedApp case final app?) OnboardingStep.app: app.name,
          if (!_selfHosted && _selectedTarget != null) OnboardingStep.where: _selectedTarget!.getTitle(context),
        },
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
