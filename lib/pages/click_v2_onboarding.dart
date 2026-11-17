import 'package:bike_control/main.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/click_v2/click_contours.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _whyUrl = 'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps/';
const _alternativesUrl = 'https://bikecontrol.app/blog/best-controller-for-indoor-cycling/';

/// The two top-level paths the explainer offers. The left-puck restart mode is
/// not a third path of its own but an add-on to [noUnlock]: it keeps the "no
/// Zwift" promise and buys the left puck back at the cost of restarts.
enum _Path { noUnlock, zwift }

/// The Zwift Click V2 unlock-mode explainer.
///
/// Zwift locks the Click V2 to their own app, and the workarounds BikeControl
/// offers are a genuine trade-off rather than a right answer. Both paths are
/// laid out side by side on one screen, with nothing pre-selected, so the
/// rider compares them before anything connects. Discovered controllers stay
/// out of the connect queue until a choice lands here.
class ClickV2OnboardingPage extends StatefulWidget {
  const ClickV2OnboardingPage({super.key});

  @override
  State<ClickV2OnboardingPage> createState() => _ClickV2OnboardingPageState();
}

class _ClickV2OnboardingPageState extends State<ClickV2OnboardingPage> {
  _Path? _path;
  bool _useLeftSide = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Reopened through "Set up again": start on what is set now, so the screen
    // doubles as a readout of the current mode. First run: nothing selected.
    switch (ClickV2Onboarding.currentChoice) {
      case ClickV2UnlockChoice.rightSideOnly:
        _path = _Path.noUnlock;
      case ClickV2UnlockChoice.bothWithLeftRestarts:
        _path = _Path.noUnlock;
        _useLeftSide = true;
      case ClickV2UnlockChoice.unlockWithZwift:
        _path = _Path.zwift;
      case null:
        break;
    }
  }

  ClickV2UnlockChoice? get _choice => switch (_path) {
    null => null,
    _Path.zwift => ClickV2UnlockChoice.unlockWithZwift,
    _Path.noUnlock => _useLeftSide ? ClickV2UnlockChoice.bothWithLeftRestarts : ClickV2UnlockChoice.rightSideOnly,
  };

  Future<void> _apply() async {
    final choice = _choice;
    // Two fast taps would otherwise both re-enter this before the first
    // await resolves; the writes are idempotent but it's wasted racy work.
    if (choice == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await switch (choice) {
        ClickV2UnlockChoice.rightSideOnly => ClickV2Onboarding.chooseRightSideOnly(),
        ClickV2UnlockChoice.bothWithLeftRestarts => ClickV2Onboarding.chooseBothWithLeftRestarts(),
        ClickV2UnlockChoice.unlockWithZwift => ClickV2Onboarding.chooseUnlockWithZwift(),
      };
    } catch (e, stack) {
      recordError(e, stack, context: 'ClickV2OnboardingPage.apply');
    }
    if (!mounted) return;
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      // Nothing to pop back to (e.g. this page is the root) — re-enable the
      // CTA rather than leaving it permanently disabled.
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    return Scaffold(
      child: SafeArea(
        // Capped at a page's width and centred like every pushed page. No
        // effect on phones, where the window is already narrower than the cap.
        child: BkPageColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.clickV2Onboarding_title).large.semiBold),
                    BkIconButton.ghost(
                      key: const ValueKey('click-onboarding-close'),
                      icon: const Icon(LucideIcons.x),
                      label: l10n.close,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.clickV2Onboarding_intro).small.muted,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Button(
                          style: const ButtonStyle.link().withPadding(padding: const EdgeInsets.symmetric(vertical: 6)),
                          onPressed: () => launchUrlString(_whyUrl),
                          trailing: const Icon(LucideIcons.externalLink, size: 14),
                          child: Text(l10n.clickV2Onboarding_whyLink).small,
                        ),
                      ),
                      const Gap(8),
                      _hero(),
                      const Gap(20),
                      RadioGroup<_Path>(
                        value: _path,
                        onChanged: _submitting ? null : (path) => setState(() => _path = path),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [_noUnlockOption(), _zwiftOption()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  /// The pucks follow the selection: the right one alone for "no unlock", both
  /// once the left one is in play. Nothing chosen yet shows both, unbadged.
  /// The one authored motion on the page: a swipe-free version of the old
  /// pager's scrub, eased between states.
  Widget _hero() {
    final choice = _choice;
    final target = choice == ClickV2UnlockChoice.rightSideOnly ? 0.0 : 1.0;
    return SizedBox(
      key: const ValueKey('click-onboarding-hero'),
      height: 156,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, page, _) => ClickContours(
            page: page,
            animate: choice != null,
            leftRestarts: choice == ClickV2UnlockChoice.bothWithLeftRestarts,
          ),
        ),
      ),
    );
  }

  Widget _noUnlockOption() {
    final l10n = context.i18n;
    final selected = _path == _Path.noUnlock;
    return _option(
      key: const ValueKey('click-onboarding-option-no-unlock'),
      value: _Path.noUnlock,
      title: l10n.clickV2Onboarding_noUnlockTitle,
      summary: l10n.clickV2Onboarding_noUnlockSummary,
      // Honest for the state the switch is in: "no drop-outs" stops being
      // true the moment the left puck joins.
      rows: _useLeftSide && selected
          ? [
              _Point.pro(l10n.clickV2Onboarding_zwiftPro1),
              _Point.warn(l10n.clickV2Onboarding_leftRestartCon),
            ]
          : [
              _Point.pro(l10n.clickV2Onboarding_rightOnlyPro2),
              _Point.con(l10n.clickV2Onboarding_rightOnlyCon1),
            ],
      extra: selected ? _leftSideToggle() : null,
    );
  }

  Widget _zwiftOption() {
    final l10n = context.i18n;
    return _option(
      key: const ValueKey('click-onboarding-option-zwift'),
      value: _Path.zwift,
      title: l10n.clickV2Onboarding_zwiftTitle,
      summary: l10n.clickV2Onboarding_zwiftSummary,
      rows: [
        _Point.pro(l10n.clickV2Onboarding_zwiftPro2),
        _Point.con(l10n.clickV2Onboarding_zwiftCon1),
        _Point.con(l10n.clickV2Onboarding_zwiftCon2),
      ],
    );
  }

  /// The opt-in for the left puck. Only shown once "no unlock" is picked, so
  /// it reads as a refinement of that choice rather than a third option
  /// competing for attention.
  Widget _leftSideToggle() {
    final l10n = context.i18n;
    return Row(
      key: const ValueKey('click-onboarding-left-toggle'),
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(l10n.clickV2Onboarding_leftToggleTitle).small.medium,
              Text(l10n.clickV2Onboarding_leftToggleSubtitle).xSmall.muted,
            ],
          ),
        ),
        Switch(
          value: _useLeftSide,
          onChanged: _submitting ? null : (value) => setState(() => _useLeftSide = value),
        ),
      ],
    );
  }

  Widget _option({
    required Key key,
    required _Path value,
    required String title,
    required String summary,
    required List<_Point> rows,
    Widget? extra,
  }) {
    final selected = _path == value;
    final cs = Theme.of(context).colorScheme;
    return RadioCard<_Path>(
      key: key,
      value: value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _RadioDot(selected: selected),
          ),
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title).semiBold,
                  const Gap(2),
                  Text(summary).small.muted,
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [for (final row in rows) _pointRow(row)],
                  ),
                  if (extra != null) ...[
                    const Gap(14),
                    Divider(color: cs.border),
                    const Gap(12),
                    extra,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointRow(_Point point) {
    final status = BkStatusColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (point.kind) {
      _PointKind.pro => (LucideIcons.circleCheck, status.success),
      _PointKind.con => (LucideIcons.circleMinus, cs.mutedForeground),
      _PointKind.warn => (LucideIcons.circleAlert, status.warning),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: color),
        ),
        Expanded(child: Text(point.text).small),
      ],
    );
  }

  Widget _footer() {
    final l10n = context.i18n;
    final choice = _choice;
    final cta = switch (choice) {
      null => l10n.clickV2Onboarding_pickFirst,
      ClickV2UnlockChoice.rightSideOnly => l10n.clickV2Onboarding_rightOnlyCta,
      ClickV2UnlockChoice.bothWithLeftRestarts => l10n.clickV2Onboarding_bothCta,
      ClickV2UnlockChoice.unlockWithZwift => l10n.clickV2Onboarding_zwiftCta,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            // Until something is picked the CTA is a quiet outline that only
            // names what is missing; a disabled primary reads as a dark slab
            // that competes with the options themselves.
            Button(
              key: const ValueKey('click-onboarding-cta'),
              style: choice == null ? const ButtonStyle.outline() : const ButtonStyle.primary(),
              alignment: Alignment.center,
              onPressed: choice == null || _submitting ? null : _apply,
              child: Text(cta),
            ),
            Center(
              child: Button(
                style: const ButtonStyle.link(size: ButtonSize.small),
                onPressed: () => launchUrlString(_alternativesUrl),
                trailing: const Icon(LucideIcons.externalLink, size: 12),
                child: Text(l10n.clickV2Onboarding_alternativesLink, textAlign: TextAlign.center).muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PointKind { pro, con, warn }

class _Point {
  final _PointKind kind;
  final String text;

  const _Point.pro(this.text) : kind = _PointKind.pro;
  const _Point.con(this.text) : kind = _PointKind.con;
  const _Point.warn(this.text) : kind = _PointKind.warn;
}

/// A plain radio indicator. RadioCard marks the selected card by its border
/// alone, which is too faint a signal for the one decision on this screen.
class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = bkAccentText(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? accent : cs.mutedForeground.withValues(alpha: 0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
        ),
      ),
    );
  }
}
