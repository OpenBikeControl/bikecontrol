import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/prop.dart' show ShimanoAuth;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Staged setup bottom-sheet UI for Shimano Di2 button mode. Kept out of the
/// device file so that stays focused on device/BLE logic. Mirrors
/// `sram_setup_sheet.dart`: it reuses the same shared building blocks (step
/// rail, stage badge, progress checklist) with Di2-specific copy, palette, and
/// a "wake your Di2" hero. There is no protocol detail here — only wiring.

/// Opens the staged setup sheet (authenticate → button mode). [operation] runs
/// with [initialPasskey] first and asks for the rider's own passkey only after
/// the Di2 rejected it; the device supplies the error classifiers.
Future<void> showShimanoSetup(
  BuildContext context, {
  required String initialPasskey,
  required Future<void> Function(String passkey) operation,
  required bool Function(Object error) isUnresponsive,
  required bool Function(Object error) isPasskeyRejected,
  required bool Function(Object error) isPairingRequired,
  VoidCallback? onUseDfly,
}) async {
  final l = context.i18n;
  await openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    barrierDismissible: false,
    builder: (sheetContext) => ShimanoGuidedSheet(
      title: l.shimanoSetup,
      intro: l.shimanoSetupIntro,
      successMessage: l.shimanoSetupSuccess,
      confirmIcon: LucideIcons.slidersHorizontal,
      runningTitle: l.shimanoSettingUp,
      successTitle: l.shimanoAllSet,
      checklistItems: [l.shimanoChecklistAuthenticating, l.shimanoChecklistActivating],
      initialPasskey: initialPasskey,
      operation: operation,
      isUnresponsive: isUnresponsive,
      isPasskeyRejected: isPasskeyRejected,
      isPairingRequired: isPairingRequired,
      onUseDfly: onUseDfly,
    ),
  );
}

/// The device-card panel: what button mode does, and the action to turn it on
/// or off. Mirrors SRAM's `_buildSetupPanel`. Until button mode is on it also
/// offers the D-Fly channel buttons, which need no pairing; with [dfly] chosen
/// it explains those and keeps button mode one tap away.
Widget shimanoSetupPanel(
  BuildContext context, {
  required bool active,
  required bool dfly,
  required VoidCallback onSetup,
  required VoidCallback onTurnOff,
  required VoidCallback onUseDfly,
}) {
  final scheme = Theme.of(context).colorScheme;
  final l = context.i18n;
  final dark = Theme.of(context).brightness == Brightness.dark;

  if (!active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dfly ? l.shimanoDflyActive : l.shimanoPanelIntro,
          style: context.typography.small.copyWith(height: 1.4, color: scheme.mutedForeground),
        ),
        const Gap(12),
        SizedBox(
          width: double.infinity,
          child: dfly
              ? SecondaryButton(
                  leading: const Icon(LucideIcons.slidersHorizontal, size: 16),
                  onPressed: onSetup,
                  child: Text(l.shimanoSetup),
                )
              : PrimaryButton(
                  leading: const Icon(LucideIcons.slidersHorizontal, size: 16),
                  onPressed: onSetup,
                  child: Text(l.shimanoSetup),
                ),
        ),
        if (!dfly) ...[
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: GhostButton(onPressed: onUseDfly, child: Text(l.shimanoUseDfly)),
          ),
        ],
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0x1A22C55E) : shimanoSuccessWash,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.circleCheck, size: 18, color: shimanoSuccess),
            const Gap(10),
            Expanded(
              child: Text(
                l.shimanoShiftingOff,
                style: context.typography.small.copyWith(fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      const Gap(12),
      SizedBox(
        width: double.infinity,
        child: SecondaryButton(
          leading: const Icon(LucideIcons.power, size: 16),
          onPressed: onTurnOff,
          child: Text(l.shimanoTurnOff),
        ),
      ),
    ],
  );
}

/// The stages the guided operation walks through. Di2 needs no mid-flow
/// authorize gesture of its own (auth is automatic), so [authorize] doubles as
/// the "wake the Di2 / press a shifter button" prompt shown on failure, and
/// [passkey] asks again after the Di2 rejected the passkey. [pair] (Windows)
/// asks the rider to pair the Di2 in Windows Settings.
enum ShimanoSetupStage { confirm, running, authorize, passkey, pair, success, error }

// ── Di2 setup/restore palette ───────────────────────────────────────────────
const Color shimanoSuccess = Color(0xFF22C55E);
const Color shimanoSuccessWash = Color(0xFFF0FDFA);
const Color _shimanoBlue = Color(0xFF2563EB);
const Color _shimanoBlueWash = Color(0xFFEFF6FF);
const Color _shimanoErrorWash = Color(0xFFFEF2F2);
const Color _shimanoChipDark = Color(0xFF0B1B34);
const Color _shimanoWhite = Color(0xFFFFFFFF);

/// The staged guided-operation sheet. Holds the stage machine
/// (confirm → running → success | authorize | error): it runs [operation],
/// showing the "wake your Di2" hero only when the derailleur didn't answer.
class ShimanoGuidedSheet extends StatefulWidget {
  final String title;
  final String intro;
  final String successMessage;
  final IconData confirmIcon;
  final String runningTitle;
  final String successTitle;
  final List<String> checklistItems;
  final String initialPasskey;
  final Future<void> Function(String passkey) operation;

  /// Whether a thrown error means the Di2 didn't answer (→ show the wake hero
  /// and let the rider retry) rather than a generic failure.
  final bool Function(Object error) isUnresponsive;

  /// Whether a thrown error means the Di2 rejected the passkey (→ ask again).
  final bool Function(Object error) isPasskeyRejected;

  /// Whether a thrown error means Windows has no usable bond with the Di2
  /// (→ pair it in Windows Settings, then retry).
  final bool Function(Object error) isPairingRequired;

  /// Keep the D-Fly channel buttons instead (offered where pairing failed);
  /// the sheet closes afterwards. Null hides the option.
  final VoidCallback? onUseDfly;

  const ShimanoGuidedSheet({
    super.key,
    required this.title,
    required this.intro,
    required this.successMessage,
    required this.confirmIcon,
    required this.runningTitle,
    required this.successTitle,
    required this.checklistItems,
    required this.initialPasskey,
    required this.operation,
    required this.isUnresponsive,
    required this.isPasskeyRejected,
    required this.isPairingRequired,
    this.onUseDfly,
  });

  @override
  State<ShimanoGuidedSheet> createState() => _ShimanoGuidedSheetState();
}

class _ShimanoGuidedSheetState extends State<ShimanoGuidedSheet> {
  var _stage = ShimanoSetupStage.confirm;
  late final _passkey = TextEditingController(text: widget.initialPasskey);

  @override
  void dispose() {
    _passkey.dispose();
    super.dispose();
  }

  Future<void> _attempt() async {
    setState(() => _stage = ShimanoSetupStage.running);
    try {
      await widget.operation(_passkey.text.trim());
      if (!mounted) return;
      setState(() => _stage = ShimanoSetupStage.success);
    } catch (e) {
      // The operation already logged the failure; here we only pick what to
      // tell the rider.
      if (!mounted) return;
      setState(() {
        _stage = widget.isPasskeyRejected(e)
            ? ShimanoSetupStage.passkey
            : widget.isPairingRequired(e)
            ? ShimanoSetupStage.pair
            : widget.isUnresponsive(e)
                ? ShimanoSetupStage.authorize
                : ShimanoSetupStage.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: shimanoGuidedBody(
              context,
              stage: _stage,
              confirmIcon: widget.confirmIcon,
              title: widget.title,
              intro: widget.intro,
              successMessage: widget.successMessage,
              runningTitle: widget.runningTitle,
              successTitle: widget.successTitle,
              checklistItems: widget.checklistItems,
              passkeyField: ShimanoPasskeyField(controller: _passkey),
              onClose: () => closeSheet(context),
              onProceed: _attempt,
              onUseDfly: widget.onUseDfly == null
                  ? null
                  : () {
                      widget.onUseDfly!();
                      closeSheet(context);
                    },
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the per-stage guided-operation content. Shared by the live bottom
/// sheet and the snapshot harness so what tests capture is exactly what ships.
Widget shimanoGuidedBody(
  BuildContext context, {
  required ShimanoSetupStage stage,
  required IconData confirmIcon,
  required String title,
  required String intro,
  required String successMessage,
  required String runningTitle,
  required String successTitle,
  required List<String> checklistItems,
  required Widget passkeyField,
  required VoidCallback onClose,
  required VoidCallback onProceed,
  VoidCallback? onUseDfly,
  int runningStep = 0,
  bool checklistAutoAdvance = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final l = context.i18n;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final reduceMotion = MediaQuery.of(context).disableAnimations;

  final IconData icon;
  final Color tone;
  final Color wash;
  final String heading;
  final String body;
  final List<Widget> actions;
  final Widget? extra;
  final int? stepIndex; // 1-based step of 2; null → no rail

  switch (stage) {
    case ShimanoSetupStage.confirm:
      icon = confirmIcon;
      tone = scheme.primary;
      wash = scheme.primary.withValues(alpha: 0.1);
      heading = title;
      body = intro;
      stepIndex = 1;
      // Most riders keep the default passkey: it is tried silently and the
      // field only appears once the Di2 rejects it ([ShimanoSetupStage.passkey]).
      extra = null;
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          trailing: const Icon(LucideIcons.arrowRight, size: 16),
          onPressed: onProceed,
          child: Text(l.continueAction),
        ),
      ];
    case ShimanoSetupStage.running:
      icon = LucideIcons.radio;
      tone = scheme.primary;
      wash = scheme.primary.withValues(alpha: 0.1);
      heading = runningTitle;
      body = l.shimanoDialogRunning;
      stepIndex = 2;
      extra = ProgressChecklist(
        items: checklistItems,
        reduceMotion: reduceMotion,
        initialStep: runningStep,
        autoAdvance: checklistAutoAdvance,
      );
      actions = const [];
    case ShimanoSetupStage.authorize:
      icon = LucideIcons.bluetooth;
      tone = _shimanoBlue;
      wash = dark ? const Color(0x1A2563EB) : _shimanoBlueWash;
      heading = l.shimanoAuthorizeTitle;
      body = l.shimanoAuthorizeBody;
      stepIndex = null;
      extra = _ShimanoDi2Hero(reduceMotion: reduceMotion);
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          leading: const Icon(LucideIcons.rotateCw, size: 16),
          onPressed: onProceed,
          child: Text(l.retry),
        ),
      ];
    case ShimanoSetupStage.passkey:
      icon = LucideIcons.keyRound;
      tone = scheme.destructive;
      wash = dark ? const Color(0x1AEF4444) : _shimanoErrorWash;
      heading = l.shimanoPasskeyWrongTitle;
      body = l.shimanoPasskeyWrongBody;
      stepIndex = null;
      extra = passkeyField;
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          leading: const Icon(LucideIcons.rotateCw, size: 16),
          onPressed: onProceed,
          child: Text(l.retry),
        ),
      ];
    case ShimanoSetupStage.pair:
      icon = LucideIcons.bluetooth;
      tone = _shimanoBlue;
      wash = dark ? const Color(0x1A2563EB) : _shimanoBlueWash;
      heading = l.shimanoPairTitle;
      body = l.shimanoPairBody;
      stepIndex = null;
      // The D-Fly channel buttons need no pairing: the way out when Windows
      // can't pair this Di2.
      extra = onUseDfly == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                leading: const Icon(LucideIcons.radio, size: 16),
                onPressed: onUseDfly,
                child: Text(l.shimanoUseDfly),
              ),
            );
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          leading: const Icon(LucideIcons.rotateCw, size: 16),
          onPressed: onProceed,
          child: Text(l.retry),
        ),
      ];
    case ShimanoSetupStage.success:
      icon = LucideIcons.circleCheck;
      tone = shimanoSuccess;
      wash = dark ? const Color(0x1A22C55E) : shimanoSuccessWash;
      heading = successTitle;
      body = successMessage;
      stepIndex = null;
      extra = null;
      actions = [
        PrimaryButton(onPressed: onClose, child: Text(l.done)),
      ];
    case ShimanoSetupStage.error:
      icon = LucideIcons.triangleAlert;
      tone = scheme.destructive;
      wash = dark ? const Color(0x1AEF4444) : _shimanoErrorWash;
      heading = l.shimanoErrorTitle;
      body = l.shimanoGenericError;
      stepIndex = null;
      extra = null;
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          leading: const Icon(LucideIcons.rotateCw, size: 16),
          onPressed: onProceed,
          child: Text(l.retry),
        ),
      ];
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      const Gap(18),
      if (stepIndex != null) ...[
        StepRail(step: stepIndex),
        const Gap(18),
      ],
      StageBadge(icon: icon, tone: tone, wash: wash, reduceMotion: reduceMotion),
      const Gap(16),
      Text(
        heading,
        style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      const Gap(8),
      Text(
        body,
        style: context.typography.small.copyWith(height: 1.5, color: scheme.mutedForeground),
      ),
      if (extra != null) ...[
        const Gap(20),
        extra,
      ],
      const Gap(24),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const Gap(8),
            action,
          ],
        ],
      ),
    ],
  );
}

/// The E-TUBE passkey input (6 digits, default 000000).
class ShimanoPasskeyField extends StatelessWidget {
  final TextEditingController controller;
  const ShimanoPasskeyField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.shimanoPasskeyLabel, style: context.typography.small.copyWith(fontWeight: FontWeight.w600)),
        const Gap(6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          placeholder: Text(ShimanoAuth.defaultPasskey),
          // The iOS number pad has no return key: close it once the passkey is
          // complete or on a tap elsewhere, else it covers Retry.
          onChanged: (value) {
            if (value.length == 6) FocusScope.of(context).unfocus();
          },
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        ),
        const Gap(6),
        Text(
          l.shimanoPasskeyHint,
          style: context.typography.xSmall.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
        ),
      ],
    );
  }
}

/// Authorize-stage hero: a Di2 chip inside two blue rings that pulse outward,
/// with a blinking LED, over a "press a shifter button" pill. All motion is
/// skipped under reduced motion (final resting state shown).
class _ShimanoDi2Hero extends StatefulWidget {
  final bool reduceMotion;
  const _ShimanoDi2Hero({required this.reduceMotion});

  @override
  State<_ShimanoDi2Hero> createState() => _ShimanoDi2HeroState();
}

class _ShimanoDi2HeroState extends State<_ShimanoDi2Hero> with TickerProviderStateMixin {
  AnimationController? _pulse;
  AnimationController? _blink;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
      _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    _blink?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_pulse != null) ...[
                _ring(0.0),
                _ring(0.5),
              ],
              _chip(),
            ],
          ),
        ),
        const Gap(16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: ShapeDecoration(
            color: dark ? const Color(0x1A2563EB) : _shimanoBlueWash,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.hand, size: 15, color: _shimanoBlue),
              const Gap(8),
              Flexible(
                child: Text(
                  context.i18n.shimanoWakeUp,
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: _shimanoBlue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ring(double phase) {
    return AnimatedBuilder(
      animation: _pulse!,
      builder: (context, _) {
        final t = (_pulse!.value + phase) % 1.0;
        final scale = 0.82 + (1.25 - 0.82) * t;
        final opacity = (0.7 * (1 - t)).clamp(0.0, 0.7);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _shimanoBlue.withValues(alpha: opacity), width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _chip() {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _shimanoChipDark, shape: BoxShape.circle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_blink != null)
            AnimatedBuilder(
              animation: _blink!,
              builder: (context, _) => _led(0.35 + 0.65 * _blink!.value),
            )
          else
            _led(1.0),
          const Gap(7),
          Text(
            'Di2',
            style: context.typography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: _shimanoWhite,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _led(double opacity) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _shimanoBlue.withValues(alpha: opacity),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: _shimanoBlue.withValues(alpha: opacity * 0.6), blurRadius: 6)],
    ),
  );
}
