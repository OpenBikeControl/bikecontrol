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
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_viewport.dart';
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
import 'package:bike_control/pages/onboarding/steps/step_gear.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart' show openTrainerSelfTest;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/device_setup_prompt.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/android.dart' show LocationRequirement;
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:bike_control/widgets/keymap/trainer_app_keymap_prompt.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const double kOnboardingDesktopBreakpoint = Breakpoints.twoPane;
const double kOnboardingBodyMaxWidth = 640;

/// Brings up the connection methods the rider turned on. The launch-time start
/// is skipped while the wizard holds the screen, so every way out of it — Start
/// riding, plan options, Later, and X — calls this. Replaceable so tests can
/// see it happen without opening real sockets.
@visibleForTesting
void Function() onboardingStartConnectionMethods = () => core.logic.startEnabledConnectionMethod(userInitiated: true);

String onboardingStepLabel(BuildContext context, OnboardingStep step) => switch (step) {
  OnboardingStep.app => context.i18n.onboardingStepApp,
  OnboardingStep.gear => context.i18n.onboardingStepGear,
  OnboardingStep.ride => context.i18n.onboardingStepConnection,
};

String onboardingStepSub(BuildContext context, OnboardingStep step) => switch (step) {
  OnboardingStep.app => context.i18n.onboardingStepAppSub,
  OnboardingStep.gear => context.i18n.onboardingStepGearSub,
  OnboardingStep.ride => context.i18n.onboardingStepConnectionSub,
};

/// Pure shell — mobile: "Step N of 3" header with Back (Close on the first
/// step) and Help, a segmented progress bar, the body, then the footer's
/// full-width pill; desktop (>=800): a step rail (grouped list) beside a
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
      // Phones show the steps as the progress bar only — the list of steps
      // lives in the rail on wide windows.
      final content = body;
      final scrolledBody = OnboardingScrollArea(
        // Keyed per step: the next step starts at the top, not wherever the
        // last one was scrolled to.
        key: ValueKey('onboarding-scroll-$step'),
        padding: EdgeInsets.fromLTRB(desktop ? 24 : 16, 8, desktop ? 24 : 16, desktop ? 24 : 32),
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
                  // Back lives up here on phones, so the footer holds the
                  // step's own choices only. The first step has nothing to go
                  // back to and offers Close instead.
                  SizedBox(
                    width: 48,
                    child: onBack != null
                        ? BkIconButton.ghost(
                            key: const ValueKey('onboarding-back'),
                            icon: Icon(LucideIcons.chevronLeft),
                            label: context.i18n.onboardingBack,
                            onPressed: onBack,
                          )
                        : onClose == null
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
            if (footerActions.isNotEmpty)
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
                        // One row, always: Back left, the primary action
                        // rightmost, and a secondary action that doesn't fit
                        // wraps onto a second line rather than dropping
                        // under the pill.
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
                            const Gap(10),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  for (final action in footerActions.skip(1).toList().reversed) ...[
                                    Flexible(
                                      child: DefaultTextStyle.merge(
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        child: BkTouchTarget(child: action),
                                      ),
                                    ),
                                    const Gap(10),
                                  ],
                                  if (footerActions.isNotEmpty) BkTouchTarget(child: footerActions.first),
                                ],
                              ),
                            ),
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

/// The step's scrolling body. Fades out above the footer instead of ending at
/// a hard edge, and while there is more below the fold a round arrow says so —
/// a fade alone didn't read as "scroll for more" (a step-1 "runs on" choice or
/// step 2's trainer could sit unseen under it). The arrow scrolls on, and goes
/// once the body has been scrolled.
class OnboardingScrollArea extends StatefulWidget {
  const OnboardingScrollArea({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  State<OnboardingScrollArea> createState() => _OnboardingScrollAreaState();
}

class _OnboardingScrollAreaState extends State<OnboardingScrollArea> {
  final _controller = ScrollController();
  bool _more = false;
  // The bottom fade, only while there is content under it: at the end it
  // would wash out the last thing on the step.
  bool _fade = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics) {
    // Only until the first scroll: by then the rider knows there is more, and
    // the arrow would just sit on top of the content.
    final more = metrics.extentAfter > 24 && metrics.extentBefore < 8;
    final fade = metrics.extentAfter > 1;
    if (more != _more || fade != _fade) {
      // Metrics notifications arrive during layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _more = more;
            _fade = fade;
          });
        }
      });
    }
    return false;
  }

  void _scrollOn() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (position.pixels + position.viewportDimension * 0.75).clamp(0.0, position.maxScrollExtent);
    if (prefersReducedMotion(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFFFFFFF), _fade ? const Color(0x00FFFFFF) : const Color(0xFFFFFFFF)],
                  stops: [0.0, 1.0],
                ).createShader(Rect.fromLTRB(0, rect.height - 32, rect.width, rect.height)),
                child: LayoutBuilder(
                  builder: (context, constraints) => OnboardingViewport(
                    bodyHeight: (constraints.maxHeight - widget.padding.vertical).clamp(0, double.infinity),
                    child: SingleChildScrollView(controller: _controller, padding: widget.padding, child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Center(
            child: IgnorePointer(
              ignoring: !_more,
              child: AnimatedOpacity(
                opacity: _more ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: BkIconButton.ghost(
                  key: const ValueKey('onboarding-scroll-more'),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.border),
                      boxShadow: [
                        BoxShadow(color: cs.foreground.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(LucideIcons.chevronDown, size: 18, color: cs.foreground),
                  ),
                  label: context.i18n.a11yScrollDown,
                  onPressed: _scrollOn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One segment per step, filled in the accent up to the current step. Finished
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
        // What a finished step settled on replaces its description — a
        // trailing value squeezed the title out of the narrow rail.
        subtitle: value ?? (showSubtitles || (!done && !active) ? onboardingStepSub(context, s) : null),
        titleColor: active ? cs.foreground : (done ? cs.foreground : cs.mutedForeground),
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
  // Set once the permission sheet has been shown, so a declined notification
  // permission is asked for once rather than on every visit to the step.
  bool _askedScanPermissions = false;
  // Android 11 and older need Location to scan for Bluetooth devices.
  bool _scanNeedsLocation = false;
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
    core.bc2BluetoothEmulator.isConnected,
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

  /// Where the picked app can run, as the app step offers it: nothing to ask
  /// for BikeControl itself, which rides right here.
  List<Target> get _targetChoices {
    final app = _selectedApp;
    if (app == null || app is BikeControl) return const [];
    return Target.supportedFor(app);
  }

  /// The target the app step settles on: the rider's pick, or the only one.
  Target? get _effectiveTarget {
    final choices = _targetChoices;
    if (choices.length == 1) return choices.single;
    return choices.contains(_selectedTarget) ? _selectedTarget : null;
  }

  bool get _appStepComplete =>
      _selectedApp != null && (_selectedApp is BikeControl || _effectiveTarget != null);

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
        if (_step == OnboardingStep.gear &&
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
        final notifier = _presses.putIfAbsent(id, () => ValueNotifier((button: null, generation: 0, trigger: null)));
        notifier.value = (button: notification.buttonsClicked.first, generation: _pressGeneration[id]!, trigger: null);
      } else if (notification is GestureNotification) {
        final notifier = _presses[notification.device.uniqueId];
        if (notifier != null) {
          notifier.value = (button: notification.button, generation: notifier.value.generation, trigger: notification.trigger);
        }
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
    // Shared with Ride's own offer, so a setup the rider closed here is not
    // opened again the moment the onboarding ends — see [DeviceSetupPrompt].
    DeviceSetupPrompt.markOffered(d);
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
      if (_step != OnboardingStep.gear) continue;
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
  /// step-entry side effect (the gear step's permission check + scan kickoff,
  /// the ride step's network check) fires exactly once, regardless of
  /// transition direction.
  void _goTo(OnboardingStep step) {
    setState(() => _step = step);
    _syncNetworkPrecheck();
    if (step == OnboardingStep.gear) _enterControllerStep();
    if (step == OnboardingStep.ride) _enterConnectionStep();
  }

  /// A network method already switched on is only re-verified here: the toggle
  /// in [setOnboardingMethodEnabled] checks on the way *on*, which a rider who
  /// arrives with it already enabled never crosses.
  Future<void> _enterConnectionStep() async {
    final app = _selectedApp;
    if (app == null) return;
    // A Bluetooth method the app step switched on (Grimpa) was held back while
    // the wizard owns the screen; with its permission granted, bring it up.
    // It checks the permission itself and stays down without it.
    if (onboardingMethodVisible(OnboardingMethod.bluetooth, app) &&
        onboardingMethodEnabled(OnboardingMethod.bluetooth, app) &&
        !onboardingMethodEnabled(OnboardingMethod.network, app)) {
      core.logic.startEnabledConnectionMethod(userInitiated: true);
    }
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

  /// The ride step's background network check, for the network method that
  /// is on (see [OnboardingNetworkPrecheckGate]). Stopped when the step is
  /// left or the method switched off.
  late final OnboardingNetworkPrecheckGate _precheckGate = OnboardingNetworkPrecheckGate()
    ..addListener(_onPrecheckChanged);

  void _syncNetworkPrecheck() {
    final wanted = _step == OnboardingStep.ride && !kIsWeb && core.logic.hasNetworkMethodEnabled;
    _precheckGate.sync(wanted: wanted, target: wanted ? currentNetworkMethodTarget() : null);
  }

  void _onPrecheckChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runPrecheckFix(NetworkFixId fix) async {
    try {
      // _sheetContext: "Switch to Local" opens a permission sheet.
      await runNetworkFix(_sheetContext, fix);
    } catch (e, s) {
      recordError(e, s, context: 'onboarding network precheck fix');
    }
    if (mounted) unawaited(_precheckGate.precheck?.run());
  }

  void _next() => _goTo(onboardingNextStep(_step));

  void _back() => _goTo(onboardingPreviousStep(_step));

  /// Whether this step asks for Android's Bluetooth advertise permission too:
  /// the picked app is reached over Bluetooth alone (Grimpa), so the Bluetooth
  /// connection method — switched on by the app step — can't start without it.
  bool get _asksBluetoothAdvertise {
    final app = _selectedApp;
    return HostPlatform.isAndroid && app != null && !_selfHosted && app.reachedOverBluetoothOnly;
  }

  /// The scan permissions, plus [_asksBluetoothAdvertise]'s when it is
  /// missing — one sheet for everything Bluetooth.
  Future<List<PlatformRequirement>> _controllerStepRequirements() async {
    final requirements = await core.permissions.getScanRequirements();
    if (!_asksBluetoothAdvertise) return requirements;
    final advertise = BluetoothAdvertiseRequirement();
    return [...requirements, if (!await advertise.getStatus()) advertise];
  }

  Future<void> _enterControllerStep() async {
    try {
      final requirements = await _controllerStepRequirements();
      if (!mounted) return;
      _scanNeedsLocation = requirements.any((r) => r is LocationRequirement);
      // Only notifications missing and already asked once: look for the
      // controller anyway rather than ask again on every visit.
      if (requirements.isEmpty ||
          (_askedScanPermissions && Permissions.blockingScan(requirements).isEmpty)) {
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
      final requirements = await _controllerStepRequirements();
      if (!mounted) return;
      if (requirements.isEmpty) {
        _startScanPhase();
        return;
      }
      _askedScanPermissions = true;
      await openPermissionSheet(_sheetContext, requirements);
      if (!mounted) return;
      // The Bluetooth method the app step switched on waited for this grant.
      if (requirements.any((r) => r is BluetoothAdvertiseRequirement)) {
        core.logic.startEnabledConnectionMethod(userInitiated: true);
      }
      final recheck = await _controllerStepRequirements();
      if (!mounted) return;
      // Declining notifications must not leave "Allow Bluetooth" doing nothing.
      if (Permissions.blockingScan(recheck).isEmpty) _startScanPhase();
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
    selfHosted: _selfHosted,
  );

  bool get _doneOffersOverlay {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    final app = _selectedApp;
    if (trainer == null || app == null) return false;
    return onboardingDoneOffersOverlay(
      app: app,
      trainerBridged: true,
      overlayOffered: trainerOverlayOffered(trainer),
      overlayEnabled: core.settings.getOverlayEnabled(),
    );
  }

  /// The overlay is on for a setup that needs it: a checklist row, where the
  /// offer stood. Only for apps that show a gear of their own — for a
  /// Bluetooth-only app (see overlayOverOtherApps) the overlay is optional,
  /// and an optional thing is no setup step.
  bool get _doneOverlayOn {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    final app = _selectedApp;
    if (trainer == null || app == null || !app.showsOwnGear) return false;
    return trainerOverlayOffered(trainer) && core.settings.getOverlayEnabled();
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

  /// The bridged trainer's resistance self-test lives in its virtual shifting
  /// settings, under "Check and calibrate".
  Future<void> _onRunTrainerCheck() async {
    final trainer = core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull;
    if (trainer == null) return;
    try {
      await openTrainerSelfTest(context, trainer);
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

  void _onSelectApp(SupportedApp app) {
    setState(() => _selectedApp = app);
  }

  Widget _body(BuildContext context) => switch (_step) {
    OnboardingStep.app => onboardingAppBody(
      context,
      // Mobile shows it on the welcome screen instead.
      showUpdateBanner: !_showedWelcome,
      selected: _selectedApp,
      onSelect: _onSelectApp,
      targets: _targetChoices,
      selectedTarget: _effectiveTarget,
      onSelectTarget: (t) => setState(() => _selectedTarget = t),
    ),
    OnboardingStep.gear => _controllerPhase == ControllerPhase.permission
        ? onboardingControllerBody(
            context,
            phase: ControllerPhase.permission,
            devices: const [],
            appName: _selectedApp?.name ?? '',
            locationNeededForBluetooth: _scanNeedsLocation,
          )
        : onboardingGearBody(
            context,
            controllerPhase: _controllerPhase,
            controllers: core.connection.controllerDevices,
            app: _selectedApp!,
            trainers: core.connection.proxyDevices,
            onPickTrainer: _onPickTrainer,
            onRescanTrainers: () {
              core.connection.performScanning();
              setState(() {});
            },
            onScanControllersAgain: _startScanPhase,
            pressedButtons: _pressedButton,
            pressGenerations: _pressGeneration,
            presses: _presses,
            onSetupDevice: (d) => unawaited(_openSetupFor(d)),
            onUpdate: () => setState(() {}),
            virtualShiftingBlocked: onboardingVirtualShiftingBlocked(_selectedApp!),
            needsSecondDevice: onboardingVsNeedsSecondDevice(_selectedApp!),
            vsDailyMinutesWithoutPro: IAPManager.instance.isProEnabledForCurrentDevice
                ? null
                : core.bridgeUsageTracker.dailyLimit.inMinutes,
          ),
    OnboardingStep.ride => onboardingDoneBody(
      context,
      app: _selectedApp!,
      controllerName: core.connection.controllerDevices.where((d) => d.isConnected).firstOrNull?.name,
      trainerName: core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull?.name,
      bridgeName: core.connection.proxyDevices.where((t) => t.isBridged).firstOrNull?.advertisementName,
      // isConnectedListenable mirrors emulator.isConnected — i.e. the
      // trainer app actually holds the virtual trainer, not just "the
      // bridge is running".
      appConnected: core.logic.connectedTrainerConnections.any((c) => c.isConnected.value),
      trainerAppConnected: core.connection.proxyDevices.any((t) => t.isConnectedListenable.value),
      reduceMotion: prefersReducedMotion(context),
      showTestMode: !IAPManager.instance.isPurchased.value,
      onPairController: () => _goTo(OnboardingStep.gear),
      onRunTrainerCheck: _onRunTrainerCheck,
      waitingOnNetworkMethod: core.logic.hasNetworkMethodEnabled,
      onTestNetwork: () => context.push(const NetworkTroubleshootingPage()),
      offerOverlay: _doneOffersOverlay,
      onShowOverlay: _onShowOverlay,
      overlayOn: _doneOverlayOn,
      networkStatus: switch (_precheckGate.precheck) {
        null => null,
        final precheck => OnboardingNetworkPrecheckCard(
          precheck: precheck,
          appName: _selectedApp!.name,
          onFix: _runPrecheckFix,
          trainerAppConnected: _precheckGate.trainerAppConnected,
        ),
      },
      connectionMethods: OnboardingMethodsDisclosure(
        app: _selectedApp!,
        onUpdate: () {
          setState(() {});
          _syncNetworkPrecheck();
        },
      ),
    ),
  };

  /// The gear step's primary button follows the trainer: connect the one
  /// found, wait while it connects, then continue.
  Widget _gearPrimary(BuildContext context) {
    final trainers = core.connection.proxyDevices;
    final app = _selectedApp!;
    if (onboardingTrainerBridged(trainers) || onboardingVirtualShiftingBlocked(app)) {
      return PrimaryButton(alignment: Alignment.center, onPressed: _next, child: Text(context.i18n.onboardingContinue));
    }
    final toConnect = onboardingGearTrainerToConnect(trainers);
    final String label;
    if (toConnect != null) {
      label = context.i18n.onboardingConnectTrainer(toConnect.name);
    } else if (trainers.any((t) => t.isStarting.value)) {
      label = context.i18n.onboardingDeviceConnecting;
    } else if (trainers.isNotEmpty) {
      label = context.i18n.onboardingTrainersFound(trainers.length);
    } else {
      label = context.i18n.lookingForSmartTrainers;
    }
    return PrimaryButton(
      key: const ValueKey('onboarding-gear-primary'),
      alignment: Alignment.center,
      onPressed: toConnect == null ? null : () => _onPickTrainer(toConnect),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  List<Widget> _footer(BuildContext context) => switch (_step) {
    OnboardingStep.app => [
      PrimaryButton(
        alignment: Alignment.center,
        onPressed: !_appStepComplete
            ? null
            : () async {
                // The rider's own mapping made for another app: ask before
                // replacing it (or keeping it) for this one.
                final keymapChoice = await askKeymapForTrainerApp(context, _selectedApp!);
                if (keymapChoice == null || !mounted) return;
                try {
                  await applyTrainerAppSelection(_selectedApp!, keymapChoice: keymapChoice);
                  // BikeControl itself pins this device in applyTrainerAppSelection.
                  if (_effectiveTarget case final target? when !_selfHosted) {
                    _selectedTarget = target;
                    await applyTargetSelection(target);
                  }
                } catch (e, s) {
                  recordError(e, s, context: 'onboarding apply trainer app selection');
                }
                _next();
              },
        child: Text(
          _selectedApp == null
              ? context.i18n.onboardingAppPickToContinue
              : context.i18n.onboardingAppContinueWith(_selectedApp!.name),
        ),
      ),
    ],
    OnboardingStep.gear => switch (_controllerPhase) {
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
      _ => [
        _gearPrimary(context),
        // Skipping the trainer is possible, but no longer an equal choice.
        if (!onboardingTrainerBridged(core.connection.proxyDevices) &&
            !onboardingVirtualShiftingBlocked(_selectedApp!))
          GhostButton(
            key: const ValueKey('onboarding-gear-skip-trainer'),
            alignment: Alignment.center,
            onPressed: _onSkipVirtualShifting,
            child: Text(context.i18n.onboardingLetAppHandleVs(_selectedApp!.name)),
          ),
      ],
    },
    OnboardingStep.ride => onboardingDoneFooter(
      context,
      state: _doneState,
      showPlanOptions: !IAPManager.instance.isPurchased.value,
      onStartRiding: () async {
        try {
          await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
          // The launch-time start was skipped while the wizard held the
          // screen; leaving it is when the enabled methods must come up.
          onboardingStartConnectionMethods();
          if (context.mounted) Navigator.of(context).pop();
        } catch (e, s) {
          recordError(e, s, context: 'onboarding done start riding');
        }
      },
      onSeePlanOptions: () async {
        try {
          await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
          onboardingStartConnectionMethods();
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
      onboardingStartConnectionMethods();
    } catch (e, s) {
      recordError(e, s, context: 'onboarding welcome later');
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  /// X leaves the wizard like "Later" minus recording it as done: the
  /// launch-time start was skipped while the wizard held the screen, so the
  /// methods the rider turned on come up now instead of staying silent.
  void _onClose() {
    try {
      onboardingStartConnectionMethods();
    } catch (e, s) {
      recordError(e, s, context: 'onboarding close');
    }
    Navigator.of(context).maybePop();
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
        // Re-keyed per screen so every one re-mounts and its contents reveal
        // themselves again. The reveal lives on the children (see
        // onboardingReveal) rather than on one wrapper, so a screen arrives in
        // reading order instead of all at once. The gear step's Bluetooth
        // permission is its own screen; a controller turning up is not — the
        // trainer card and its animation stay put.
        body: KeyedSubtree(
          key: ValueKey(
            'onboarding-body-$_step-${_step == OnboardingStep.gear && _controllerPhase == ControllerPhase.permission}',
          ),
          child: _body(overlayContext),
        ),
        footerActions: _footer(overlayContext),
        onBack: _step == OnboardingStep.app ? null : _back,
        onHelp: () => openOnboardingHelpSheet(overlayContext, onboardingHelpTopicFor(_step)),
        onClose: _onClose,
        stepValues: {
          if (_selectedApp case final app?)
            OnboardingStep.app: _selfHosted || _selectedTarget == null
                ? app.name
                : '${app.name} · ${_selectedTarget!.getTitle(context)}',
        },
        onSelectStep: _goTo,
      ),
    );
  }
}
