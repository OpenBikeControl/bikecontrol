import 'dart:async';

import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
import 'package:prop/prop.dart' show ShimanoAuth, ShimanoShifter;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Staged setup bottom-sheet UI for Shimano Di2 button mode. Kept out of the
/// device file so that stays focused on device/BLE logic. Mirrors
/// `sram_setup_sheet.dart`: it reuses the same shared building blocks (step
/// rail, stage badge, progress checklist) with Di2-specific copy, palette, and
/// a "wake your Di2" hero. There is no protocol detail here — only wiring.

/// How the Di2 shifters become BikeControl buttons.
enum ShimanoSetupMode {
  /// The paddles are set to D-Fly channels (after a backup): the Di2 never
  /// shifts with them, connected or not, until the rider restores them.
  channels,

  /// Nothing is changed: while BikeControl is connected the Di2 doesn't shift
  /// and every press arrives as a button. A dropped link shifts for real.
  buttons,
}

/// Asks how BikeControl should use the Di2 ([ShimanoSetupMode]) and hands the
/// choice to [onChoose] once the sheet has closed.
Future<void> showShimanoModeChooser(
  BuildContext context, {
  required void Function(ShimanoSetupMode mode) onChoose,
}) async {
  ShimanoSetupMode? chosen;
  await openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    barrierDismissible: false,
    builder: (sheetContext) => _ShimanoModeChooser(onChoose: (mode) => chosen = mode),
  );
  if (chosen case final mode?) onChoose(mode);
}

class _ShimanoModeChooser extends StatefulWidget {
  final void Function(ShimanoSetupMode mode) onChoose;
  const _ShimanoModeChooser({required this.onChoose});

  @override
  State<_ShimanoModeChooser> createState() => _ShimanoModeChooserState();
}

class _ShimanoModeChooserState extends State<_ShimanoModeChooser> {
  var _selected = ShimanoSetupMode.channels;

  @override
  Widget build(BuildContext context) => _sheetFrame(
        context,
        shimanoModeChoiceBody(
          context,
          selected: _selected,
          onSelect: (mode) => setState(() => _selected = mode),
          onClose: () => closeSheet(context),
          onContinue: () {
            widget.onChoose(_selected);
            closeSheet(context);
          },
        ),
      );
}

/// The mode choice's content. Shared by the live sheet and the snapshot
/// harness so what tests capture is exactly what ships.
Widget shimanoModeChoiceBody(
  BuildContext context, {
  required ShimanoSetupMode selected,
  required void Function(ShimanoSetupMode mode) onSelect,
  required VoidCallback onClose,
  required VoidCallback onContinue,
}) {
  final scheme = Theme.of(context).colorScheme;
  final l = context.i18n;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Gap(18),
      const StepRail(step: 1, count: 3),
      const Gap(18),
      Text(l.shimanoChooseTitle, style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w700)),
      const Gap(8),
      Text(l.shimanoChooseIntro, style: context.typography.small.copyWith(height: 1.5, color: scheme.mutedForeground)),
      const Gap(20),
      _ShimanoModeOption(
        selected: selected == ShimanoSetupMode.channels,
        icon: LucideIcons.radio,
        title: l.shimanoModeChannelsTitle,
        badge: l.recommended,
        body: l.shimanoModeChannelsBody,
        note: l.shimanoModeChannelsNote,
        noteIcon: LucideIcons.info,
        noteColor: scheme.mutedForeground,
        onTap: () => onSelect(ShimanoSetupMode.channels),
      ),
      const Gap(12),
      _ShimanoModeOption(
        selected: selected == ShimanoSetupMode.buttons,
        icon: LucideIcons.gamepad2,
        title: l.shimanoModeButtonsTitle,
        body: l.shimanoModeButtonsBody,
        note: l.shimanoModeButtonsWarning,
        noteIcon: LucideIcons.triangleAlert,
        noteColor: _shimanoWarning,
        onTap: () => onSelect(ShimanoSetupMode.buttons),
      ),
      const Gap(24),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GhostButton(onPressed: onClose, child: Text(l.cancel)),
          const Gap(8),
          PrimaryButton(
            trailing: const Icon(LucideIcons.arrowRight, size: 16),
            onPressed: onContinue,
            child: Text(l.continueAction),
          ),
        ],
      ),
    ],
  );
}

class _ShimanoModeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String? badge;
  final String body;
  final String note;
  final IconData noteIcon;
  final Color noteColor;
  final VoidCallback onTap;

  const _ShimanoModeOption({
    required this.selected,
    required this.icon,
    required this.title,
    this.badge,
    required this.body,
    required this.note,
    required this.noteIcon,
    required this.noteColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Button.card(
      onPressed: onTap,
      style: ButtonVariance.card.copyWith(
        decoration: (context, states, value) => (value as BoxDecoration).copyWith(
          border: Border.all(color: selected ? scheme.primary : scheme.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: selected ? scheme.primary : scheme.mutedForeground),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: context.typography.base.copyWith(fontWeight: FontWeight.w700)),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: ShapeDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          badge!,
                          style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                        ),
                      ),
                  ],
                ),
                const Gap(6),
                Text(body, style: context.typography.small.copyWith(height: 1.45, color: scheme.mutedForeground)),
                const Gap(8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(noteIcon, size: 14, color: noteColor),
                    ),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        note,
                        style: context.typography.xSmall.copyWith(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: noteColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(8),
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 20,
            color: selected ? scheme.primary : scheme.border,
          ),
        ],
      ),
    );
  }
}

/// The sheet's frame: centred, at most 480 wide, and scrollable so the longer
/// stages (the mode choice) still fit a small phone.
Widget _sheetFrame(BuildContext context, Widget body) => SafeArea(
      top: false,
      child: SingleChildScrollView(
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
              child: body,
            ),
          ),
        ),
      ),
    );

/// Opens the staged setup sheet (authenticate → [operation]). [operation]
/// runs with [initialPasskey] first and asks for the rider's own passkey only
/// after the Di2 rejected it; the device supplies the error classifiers.
/// While [shifters] is non-null the running stage asks the rider to press a
/// button on each shifter and ticks off the ones seen. [afterChooser] numbers
/// the steps after the mode choice.
Future<void> showShimanoSetup(
  BuildContext context, {
  required String title,
  required String intro,
  required String successMessage,
  required IconData confirmIcon,
  required String runningTitle,
  required String successTitle,
  required List<String> checklistItems,
  required String initialPasskey,
  required Future<void> Function(String passkey) operation,
  required bool Function(Object error) isUnresponsive,
  required bool Function(Object error) isPasskeyRejected,
  required bool Function(Object error) isPairingRequired,
  bool Function(Object error)? isWiredShifters,
  bool Function(Object error)? isRejected,
  VoidCallback? onUseButtonMode,
  ValueListenable<ShimanoShifterAsk?>? shifters,
  VoidCallback? onCancelShifters,
  bool afterChooser = false,
  VoidCallback? onUseDfly,
}) async {
  await openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    barrierDismissible: false,
    builder: (sheetContext) => ShimanoGuidedSheet(
      title: title,
      intro: intro,
      successMessage: successMessage,
      confirmIcon: confirmIcon,
      runningTitle: runningTitle,
      successTitle: successTitle,
      checklistItems: checklistItems,
      initialPasskey: initialPasskey,
      operation: operation,
      isUnresponsive: isUnresponsive,
      isPasskeyRejected: isPasskeyRejected,
      isPairingRequired: isPairingRequired,
      isWiredShifters: isWiredShifters,
      isRejected: isRejected,
      onUseButtonMode: onUseButtonMode,
      shifters: shifters,
      onCancelShifters: onCancelShifters,
      afterChooser: afterChooser,
      onUseDfly: onUseDfly,
    ),
  );
}

/// The device-card panel: how the Di2 shifters reach BikeControl right now,
/// and the actions to set that up, restore the rider's shifting or change the
/// setup. Mirrors SRAM's `_buildSetupPanel`.
///
/// - nothing set up: what this is + "Use Di2 buttons" (opens the mode choice)
/// - E-TUBE channels: active status + restore (when BikeControl changed the
///   switches) + change setup
/// - button mode: active status + a one-time warning that a dropped link
///   shifts for real + turn off
Widget shimanoSetupPanel(
  BuildContext context, {
  required bool buttonMode,
  required bool channels,
  required bool canRestore,
  required bool showButtonModeWarning,
  required VoidCallback onSetup,
  required VoidCallback onRestore,
  required VoidCallback onTurnOff,
  required VoidCallback onSwitchToChannels,
  required VoidCallback onDismissWarning,
}) {
  final scheme = Theme.of(context).colorScheme;
  final l = context.i18n;
  final dark = Theme.of(context).brightness == Brightness.dark;

  Widget status(String text) => Container(
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
              child: Text(text, style: context.typography.small.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
            ),
          ],
        ),
      );

  Widget wide(Widget button) => SizedBox(width: double.infinity, child: button);

  final restore = wide(
    PrimaryButton(
      leading: const Icon(LucideIcons.rotateCcw, size: 16),
      onPressed: onRestore,
      child: Text(l.shimanoRestore),
    ),
  );

  if (buttonMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status(l.shimanoShiftingOff),
        if (showButtonModeWarning) ...[
          const Gap(10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: dark ? const Color(0x1AF59E0B) : _shimanoWarningWash,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.triangleAlert, size: 18, color: _shimanoWarning),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        l.shimanoButtonModeWarning,
                        style: context.typography.small.copyWith(height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(onPressed: onDismissWarning, child: Text(l.gotIt)),
                    GhostButton(onPressed: onSwitchToChannels, child: Text(l.shimanoSwitchToChannels)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const Gap(12),
        if (canRestore) ...[restore, const Gap(8)],
        wide(
          SecondaryButton(
            leading: const Icon(LucideIcons.power, size: 16),
            onPressed: onTurnOff,
            child: Text(l.shimanoTurnOff),
          ),
        ),
      ],
    );
  }

  if (channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canRestore)
          status(l.shimanoChannelsActive)
        else
          Text(l.shimanoDflyActive, style: context.typography.small.copyWith(height: 1.4, color: scheme.mutedForeground)),
        const Gap(12),
        if (canRestore) ...[restore, const Gap(8)],
        wide(
          SecondaryButton(
            leading: const Icon(LucideIcons.slidersHorizontal, size: 16),
            onPressed: onSetup,
            child: Text(l.shimanoChangeSetup),
          ),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.shimanoPanelIntro, style: context.typography.small.copyWith(height: 1.4, color: scheme.mutedForeground)),
      const Gap(12),
      wide(
        PrimaryButton(
          leading: const Icon(LucideIcons.slidersHorizontal, size: 16),
          onPressed: onSetup,
          child: Text(l.shimanoSetup),
        ),
      ),
      if (canRestore) ...[const Gap(8), restore],
    ],
  );
}

/// The rider cancelled channel setup or restore while it waited for a press.
class ShimanoSetupCancelled implements Exception {
  const ShimanoSetupCancelled();

  @override
  String toString() => 'ShimanoSetupCancelled';
}

/// What channel setup or restore waits for: a press on each shifter so
/// BikeControl reads its setting, then, while [saving], another press on each
/// so the Di2 saves the new one. [done] are the shifters already through,
/// [next] the one whose press saves its setting now (the Di2 saves one
/// shifter at a time). [single]: only one shifter takes part (a Di2 with one
/// shifter, or one restored alone); its side is not reliable then, as a lone
/// right shifter can report as the left one.
class ShimanoShifterAsk {
  final Set<ShimanoShifter> done;
  final bool saving;
  final ShimanoShifter? next;
  final bool single;
  const ShimanoShifterAsk(this.done, {this.saving = false, this.next, this.single = false});

  @override
  bool operator ==(Object other) =>
      other is ShimanoShifterAsk &&
      other.saving == saving &&
      other.next == next &&
      other.single == single &&
      setEquals(other.done, done);

  @override
  int get hashCode => Object.hash(saving, next, single, Object.hashAllUnordered(done));

  @override
  String toString() =>
      'ShimanoShifterAsk(${done.map((s) => s.name).join(', ')}${saving ? ', saving' : ''}'
      '${next != null ? ', next ${next!.name}' : ''}${single ? ', single' : ''})';
}

/// The two shifters the running stage asks the rider to press, ticked off as
/// their presses arrive; one, with no side named, when [single].
class ShimanoShifterPrompt extends StatelessWidget {
  final Set<ShimanoShifter> seen;

  /// While [saving], the one shifter to press now (none while its setting is
  /// still on the way); the others wait their turn.
  final bool saving;
  final ShimanoShifter? next;
  final bool single;
  const ShimanoShifterPrompt({super.key, required this.seen, this.saving = false, this.next, this.single = false});

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    if (single) {
      return _ShifterPill(
        label: l.shimanoShifterSingle,
        done: seen.isNotEmpty,
        waiting: saving && next == null && seen.isEmpty,
      );
    }
    return Row(
      children: [
        for (final (i, (shifter, label)) in [
          (ShimanoShifter.left, l.shimanoShifterLeft),
          (ShimanoShifter.right, l.shimanoShifterRight),
        ].indexed) ...[
          if (i > 0) const Gap(10),
          Expanded(
            child: _ShifterPill(
              label: label,
              done: seen.contains(shifter),
              waiting: saving && next != shifter && !seen.contains(shifter),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShifterPill extends StatelessWidget {
  final String label;
  final bool done;
  final bool waiting;
  const _ShifterPill({required this.label, required this.done, this.waiting = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = done ? shimanoSuccess : _shimanoBlue;
    final Color background;
    final Color border;
    final Color iconColor;
    final Color labelColor;
    if (done) {
      background = dark ? const Color(0x1A22C55E) : shimanoSuccessWash;
      border = tone.withValues(alpha: 0.35);
      iconColor = tone;
      labelColor = scheme.foreground;
    } else if (waiting) {
      background = scheme.muted.withValues(alpha: 0.5);
      border = scheme.border;
      iconColor = scheme.mutedForeground;
      labelColor = scheme.mutedForeground;
    } else {
      background = dark ? const Color(0x1A2563EB) : _shimanoBlueWash;
      border = tone.withValues(alpha: 0.35);
      iconColor = tone;
      labelColor = _shimanoBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            done
                ? LucideIcons.circleCheck
                : waiting
                ? LucideIcons.hourglass
                : LucideIcons.hand,
            size: 18,
            color: iconColor,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              label,
              style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: labelColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stages the guided operation walks through. Di2 needs no mid-flow
/// authorize gesture of its own (auth is automatic), so [authorize] doubles as
/// the "wake the Di2 / press a shifter button" prompt shown on failure, and
/// [passkey] asks again after the Di2 rejected the passkey. [pair] (Windows)
/// asks the rider to pair the Di2 in Windows Settings.
enum ShimanoSetupStage { confirm, running, authorize, passkey, pair, wired, rejected, success, error }

// ── Di2 setup/restore palette ───────────────────────────────────────────────
const Color shimanoSuccess = Color(0xFF22C55E);
const Color shimanoSuccessWash = Color(0xFFF0FDFA);
const Color _shimanoBlue = Color(0xFF2563EB);
const Color _shimanoBlueWash = Color(0xFFEFF6FF);
const Color _shimanoErrorWash = Color(0xFFFEF2F2);
const Color _shimanoWarning = Color(0xFFD97706);
const Color _shimanoWarningWash = Color(0xFFFFFBEB);
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

  /// Whether a thrown error means the shifters are wired, which the
  /// operation can't handle (→ offer [onUseButtonMode]).
  final bool Function(Object error)? isWiredShifters;

  /// Whether a thrown error means a shifter turned the new setting down, which
  /// trying again won't change (→ set the channels in E-TUBE, or
  /// [onUseButtonMode]). Set, the step that saves the setting on the shifters
  /// also offers the E-TUBE app once it takes [etubeOfferDelay], and any
  /// failure there ends on it too.
  final bool Function(Object error)? isRejected;

  /// How long the saving step runs before it offers the E-TUBE app.
  final Duration etubeOfferDelay;

  /// Set up button mode instead (offered for wired shifters); the sheet
  /// closes first.
  final VoidCallback? onUseButtonMode;

  /// Keep the D-Fly channel buttons instead (offered where pairing failed);
  /// the sheet closes afterwards. Null hides the option.
  final VoidCallback? onUseDfly;

  /// What [operation] waits for the rider to press, null while it doesn't.
  final ValueListenable<ShimanoShifterAsk?>? shifters;

  /// Stops [operation] while it waits for a press; the sheet closes.
  final VoidCallback? onCancelShifters;

  /// Opened after the mode choice: the step rail counts that step too.
  final bool afterChooser;

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
    this.isWiredShifters,
    this.isRejected,
    this.onUseButtonMode,
    this.onUseDfly,
    this.shifters,
    this.onCancelShifters,
    this.afterChooser = false,
    this.etubeOfferDelay = const Duration(seconds: 10),
  });

  @override
  State<ShimanoGuidedSheet> createState() => _ShimanoGuidedSheetState();
}

class _ShimanoGuidedSheetState extends State<ShimanoGuidedSheet> {
  var _stage = ShimanoSetupStage.confirm;
  late final _passkey = TextEditingController(text: widget.initialPasskey);

  /// This attempt reached the step that saves the setting on the shifters.
  bool _saving = false;

  /// That step took long enough to offer the E-TUBE app instead.
  bool _offerEtube = false;
  Timer? _etubeTimer;

  bool get _etubeFallback => widget.isRejected != null && widget.onCancelShifters != null;

  @override
  void initState() {
    super.initState();
    widget.shifters?.addListener(_onShifters);
  }

  @override
  void dispose() {
    widget.shifters?.removeListener(_onShifters);
    _etubeTimer?.cancel();
    _passkey.dispose();
    super.dispose();
  }

  void _onShifters() {
    if (_saving || !(widget.shifters?.value?.saving ?? false)) return;
    _saving = true;
    if (!_etubeFallback) return;
    _etubeTimer = Timer(widget.etubeOfferDelay, () {
      if (mounted && _stage == ShimanoSetupStage.running) setState(() => _offerEtube = true);
    });
  }

  /// Give up on the saving step: the setup stops, the failure that follows
  /// ends on the E-TUBE app.
  void _useEtube() => widget.onCancelShifters!();

  Future<void> _attempt() async {
    _etubeTimer?.cancel();
    _saving = false;
    _offerEtube = false;
    setState(() => _stage = ShimanoSetupStage.running);
    try {
      await widget.operation(_passkey.text.trim());
      if (!mounted) return;
      setState(() => _stage = ShimanoSetupStage.success);
    } catch (e) {
      // The operation already logged the failure; here we only pick what to
      // tell the rider.
      _etubeTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _offerEtube = false;
        // Past the passkey and the reading of the shifters, whatever stops the
        // saving step won't go better on a retry.
        _stage = _saving && _etubeFallback
            ? ShimanoSetupStage.rejected
            : widget.isPasskeyRejected(e)
            ? ShimanoSetupStage.passkey
            : widget.isPairingRequired(e)
            ? ShimanoSetupStage.pair
            : widget.isWiredShifters?.call(e) ?? false
            ? ShimanoSetupStage.wired
            : widget.isRejected?.call(e) ?? false
            ? ShimanoSetupStage.rejected
            : widget.isUnresponsive(e)
                ? ShimanoSetupStage.authorize
                : ShimanoSetupStage.error;
      });
    }
  }

  Widget _body(BuildContext context, ShimanoShifterAsk? shifterAsk) => shimanoGuidedBody(
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
        shifterAsk: shifterAsk,
        onCancelShifters: widget.onCancelShifters == null
            ? null
            : () {
                widget.onCancelShifters!();
                closeSheet(context);
              },
        afterChooser: widget.afterChooser,
        onUseEtube: _offerEtube ? _useEtube : null,
        onUseButtonMode: widget.onUseButtonMode == null
            ? null
            : () {
                closeSheet(context);
                widget.onUseButtonMode!();
              },
        onUseDfly: widget.onUseDfly == null
            ? null
            : () {
                widget.onUseDfly!();
                closeSheet(context);
              },
      );

  @override
  Widget build(BuildContext context) {
    final shifters = widget.shifters;
    return _sheetFrame(
      context,
      shifters == null
          ? _body(context, null)
          : ValueListenableBuilder(valueListenable: shifters, builder: (context, seen, _) => _body(context, seen)),
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
  VoidCallback? onUseButtonMode,
  ShimanoShifterAsk? shifterAsk,
  VoidCallback? onCancelShifters,
  VoidCallback? onUseEtube,
  bool afterChooser = false,
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
    case ShimanoSetupStage.running when shifterAsk != null:
      icon = LucideIcons.hand;
      tone = _shimanoBlue;
      wash = dark ? const Color(0x1A2563EB) : _shimanoBlueWash;
      final single = shifterAsk.single;
      heading = switch ((shifterAsk.saving, single)) {
        (true, true) => l.shimanoSaveShifterTitle,
        (true, false) => l.shimanoSaveShiftersTitle,
        (false, true) => l.shimanoPressShifterTitle,
        (false, false) => l.shimanoPressShiftersTitle,
      };
      body = switch ((shifterAsk.saving, single)) {
        (true, true) => l.shimanoSaveShifterBody,
        (true, false) => l.shimanoSaveShiftersBody,
        (false, true) => l.shimanoPressShifterBody,
        (false, false) => l.shimanoPressShiftersBody,
      };
      stepIndex = 2;
      final prompt = ShimanoShifterPrompt(
        seen: shifterAsk.done,
        saving: shifterAsk.saving,
        next: shifterAsk.next,
        single: single,
      );
      // With one shifter in, the setup still waits for the other: a Di2 with
      // only that one goes on after a pause the rider should know about.
      extra = !shifterAsk.saving && !single && shifterAsk.done.length == 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                prompt,
                const Gap(10),
                Text(
                  l.shimanoOneShifterHint,
                  style: context.typography.small.copyWith(color: scheme.mutedForeground),
                ),
              ],
            )
          : shifterAsk.saving && onUseEtube != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                prompt,
                const Gap(10),
                SecondaryButton(
                  leading: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: onUseEtube,
                  child: Text(l.shimanoUseEtubeInstead),
                ),
              ],
            )
          : prompt;
      actions = [if (onCancelShifters != null) GhostButton(onPressed: onCancelShifters, child: Text(l.cancel))];
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
    case ShimanoSetupStage.wired || ShimanoSetupStage.rejected:
      final wired = stage == ShimanoSetupStage.wired;
      icon = wired ? LucideIcons.cable : LucideIcons.circleSlash;
      tone = _shimanoWarning;
      wash = dark ? const Color(0x1AF59E0B) : _shimanoWarningWash;
      heading = wired ? l.shimanoWiredTitle : l.shimanoRejectedTitle;
      body = wired ? l.shimanoWiredBody : l.shimanoRejectedBody;
      stepIndex = null;
      // Trying again can't work: the way on is the D-Fly channels set in
      // E-TUBE (both levers) or button mode.
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
        if (onUseButtonMode != null)
          PrimaryButton(
            leading: const Icon(LucideIcons.gamepad2, size: 16),
            onPressed: onUseButtonMode,
            child: Text(l.shimanoUseButtonMode),
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
        afterChooser ? StepRail(step: stepIndex + 1, count: 3) : StepRail(step: stepIndex),
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
