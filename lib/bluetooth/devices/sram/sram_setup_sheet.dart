import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/prop.dart' show SramBondException;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The staged setup/restore bottom-sheet UI for [SramAxs]. Kept out of the
/// device file so that stays focused on device/BLE logic. The reusable
/// building blocks (step rail, stage badge, progress checklist) live in
/// `widgets/guided_operation_sheet.dart`; what's here is the SRAM-specific
/// composition, copy, palette and the AXS "press & hold" hero.

/// The stages the guided operation walks through.
enum SramSetupStage { confirm, running, authorize, success, error }

// ── SRAM setup/restore palette ──────────────────────────────────────────────
// `sramSuccess`/`sramSuccessWash` are also used by the device card's status
// strip, so they're public; the rest are local to this sheet.
const Color sramSuccess = Color(0xFF22C55E);
const Color sramSuccessWash = Color(0xFFF0FDFA);
const Color _sramAmber = Color(0xFFF59E0B);
const Color _sramAmberWash = Color(0xFFFFFBEB);
const Color _sramErrorWash = Color(0xFFFEF2F2);
const Color _sramChipDark = Color(0xFF1B2430);
const Color _sramWhite = Color(0xFFFFFFFF);

/// The staged guided-operation sheet. Holds the stage machine
/// (confirm → running → success | authorize | error): it runs [operation],
/// showing the authorize hero only when a fresh bond turns out to be needed.
class SramGuidedSheet extends StatefulWidget {
  final String title;
  final String intro;
  final String successMessage;
  final IconData confirmIcon;
  final String runningTitle;
  final String successTitle;
  final List<String> checklistItems;
  final Future<void> Function() operation;

  const SramGuidedSheet({
    super.key,
    required this.title,
    required this.intro,
    required this.successMessage,
    required this.confirmIcon,
    required this.runningTitle,
    required this.successTitle,
    required this.checklistItems,
    required this.operation,
  });

  @override
  State<SramGuidedSheet> createState() => _SramGuidedSheetState();
}

class _SramGuidedSheetState extends State<SramGuidedSheet> {
  var _stage = SramSetupStage.confirm;

  Future<void> _attempt() async {
    setState(() => _stage = SramSetupStage.running);
    try {
      await widget.operation();
      if (!mounted) return;
      setState(() => _stage = SramSetupStage.success);
    } on SramBondException {
      // A fresh bond is needed (no valid key). Only NOW do we ask the user to
      // authorize — when already bonded this never shows.
      if (!mounted) return;
      setState(() => _stage = SramSetupStage.authorize);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = SramSetupStage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The bottom sheet spans the full width of the window; on a wide display
    // (desktop) that stretches the content unpleasantly. Cap it and centre it
    // horizontally. `heightFactor: 1` keeps the sheet shrink-wrapped to its
    // content height — without it, Center would expand to the full window.
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
            child: sramGuidedBody(
              context,
              stage: _stage,
              confirmIcon: widget.confirmIcon,
              title: widget.title,
              intro: widget.intro,
              successMessage: widget.successMessage,
              runningTitle: widget.runningTitle,
              successTitle: widget.successTitle,
              checklistItems: widget.checklistItems,
              onClose: () => closeSheet(context),
              onProceed: _attempt,
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the per-stage guided-operation content (step rail, icon badge, title,
/// body, checklist / AXS hero, actions). Shared by the live bottom sheet and the
/// snapshot harness so what tests capture is exactly what ships. [onProceed]
/// drives Continue/Retry; [onClose] drives Cancel/Done.
Widget sramGuidedBody(
  BuildContext context, {
  required SramSetupStage stage,
  required IconData confirmIcon,
  required String title,
  required String intro,
  required String successMessage,
  required String runningTitle,
  required String successTitle,
  required List<String> checklistItems,
  required VoidCallback onClose,
  required VoidCallback onProceed,
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
    case SramSetupStage.confirm:
      icon = confirmIcon;
      tone = scheme.primary;
      wash = scheme.primary.withValues(alpha: 0.1);
      heading = title;
      body = intro;
      stepIndex = 1;
      extra = null;
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          trailing: const Icon(LucideIcons.arrowRight, size: 16),
          onPressed: onProceed,
          child: Text(l.continueAction),
        ),
      ];
    case SramSetupStage.running:
      icon = LucideIcons.radio;
      tone = scheme.primary;
      wash = scheme.primary.withValues(alpha: 0.1);
      heading = runningTitle;
      body = l.sramDialogRunning;
      stepIndex = 2;
      extra = ProgressChecklist(
        items: checklistItems,
        reduceMotion: reduceMotion,
        initialStep: runningStep,
        autoAdvance: checklistAutoAdvance,
      );
      actions = const [];
    case SramSetupStage.authorize:
      icon = LucideIcons.keyRound;
      tone = _sramAmber;
      wash = dark ? const Color(0x1AF59E0B) : _sramAmberWash;
      heading = l.sramAuthorizeTitle;
      body = l.sramAuthorizeBody;
      stepIndex = null;
      extra = _SramAxsHero(reduceMotion: reduceMotion);
      actions = [
        GhostButton(onPressed: onClose, child: Text(l.cancel)),
        PrimaryButton(
          leading: const Icon(LucideIcons.rotateCw, size: 16),
          onPressed: onProceed,
          child: Text(l.retry),
        ),
      ];
    case SramSetupStage.success:
      icon = LucideIcons.circleCheck;
      tone = sramSuccess;
      wash = dark ? const Color(0x1A22C55E) : sramSuccessWash;
      heading = successTitle;
      body = successMessage;
      stepIndex = null;
      extra = null;
      actions = [
        PrimaryButton(onPressed: onClose, child: Text(l.done)),
      ];
    case SramSetupStage.error:
      icon = LucideIcons.triangleAlert;
      tone = scheme.destructive;
      wash = dark ? const Color(0x1AEF4444) : _sramErrorWash;
      heading = l.sramErrorTitle;
      body = l.sramGenericError;
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

/// Authorize-stage hero: an AXS chip inside two amber rings that pulse outward,
/// with a blinking LED, over a "press & hold" pill. All motion is skipped under
/// reduced motion (final resting state shown).
class _SramAxsHero extends StatefulWidget {
  final bool reduceMotion;
  const _SramAxsHero({required this.reduceMotion});

  @override
  State<_SramAxsHero> createState() => _SramAxsHeroState();
}

class _SramAxsHeroState extends State<_SramAxsHero> with TickerProviderStateMixin {
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
            color: dark ? const Color(0x1AF59E0B) : _sramAmberWash,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.hand, size: 15, color: _sramAmber),
              const Gap(8),
              Flexible(
                child: Text(
                  context.i18n.sramPressHold,
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: _sramAmber),
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
              border: Border.all(color: _sramAmber.withValues(alpha: opacity), width: 2),
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
      decoration: const BoxDecoration(color: _sramChipDark, shape: BoxShape.circle),
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
            'AXS',
            style: context.typography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: _sramWhite,
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
      color: _sramAmber.withValues(alpha: opacity),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: _sramAmber.withValues(alpha: opacity * 0.6), blurRadius: 6)],
    ),
  );
}
