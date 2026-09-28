import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/click_v2/click_contours.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _whyUrl = 'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps/';
const _alternativesUrl = 'https://bikecontrol.app/blog/best-controller-for-indoor-cycling/';

/// The one-time Zwift Click V2 unlock-mode explainer.
///
/// Zwift locks the Click V2 to their own app, and the two workarounds
/// BikeControl offers are a genuine trade-off rather than a right answer — so
/// this lays both out side by side before anything connects. Discovered
/// controllers stay out of the connect queue until a choice lands here.
class ClickV2OnboardingPage extends StatefulWidget {
  const ClickV2OnboardingPage({super.key});

  @override
  State<ClickV2OnboardingPage> createState() => _ClickV2OnboardingPageState();
}

class _ClickV2OnboardingPageState extends State<ClickV2OnboardingPage> with SingleTickerProviderStateMixin {
  // Page 0 = left-side-only explanation, page 1 = unlock-with-Zwift
  // explanation, page 2 = the decision itself. Both the dot indicator and the
  // dots' active-index check read this constant so the two cannot drift.
  static const _pageCount = 3;

  final _controller = PageController();
  double _page = 0;
  bool _submitting = false;

  // Drives the pro/con rows' one-shot staggered entrance. PageView (without a
  // builder) constructs both option pages eagerly, so this fires for both at
  // load time rather than when a page actually becomes active.
  late final AnimationController _rows = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  // One CurvedAnimation per staggered index, built once and reused. A fresh
  // CurvedAnimation registers a status listener on its parent (_rows) in its
  // own constructor and is never disposed on its own — building one per row
  // per build (as `_staggered` used to) piles up listeners forever, since
  // _onScroll's setState fires on every scroll frame. `_option`'s pro/con
  // rows use indices 0..3 (2 pros + 2 cons each); `_decision`'s two buttons
  // reuse indices 0-1 of the same sequence -- 4 entries covers every caller.
  static const _staggerCurveCount = 4;
  late final List<CurvedAnimation> _staggerCurves;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _staggerCurves = List.generate(_staggerCurveCount, (index) {
      final start = (index * 0.15).clamp(0.0, 0.6);
      return CurvedAnimation(
        parent: _rows,
        curve: Interval(start, 1, curve: Curves.easeOut),
      );
    });
  }

  void _onScroll() {
    // The hero interpolates on the fractional page value so a swipe scrubs it
    // continuously instead of snapping at the page boundary.
    final page = _controller.page;
    if (page != null && page != _page) {
      setState(() => _page = page);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    for (final curve in _staggerCurves) {
      curve.dispose();
    }
    _rows.dispose();
    super.dispose();
  }

  Future<void> _choose(Future<void> Function() apply) async {
    // Two fast taps would otherwise both re-enter this before the first
    // await resolves; the writes are idempotent but it's wasted racy work.
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await apply();
    } catch (e, stack) {
      recordError(e, stack, context: 'ClickV2OnboardingPage.choose');
    }
    if (!mounted) return;
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      // Nothing to pop back to (e.g. this page is the root) — re-enable the
      // CTAs rather than leaving them permanently disabled.
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    return Scaffold(
      child: SafeArea(
        // Stretched full window width on desktop before this fix. Capped
        // the same way the Help Center and the instruction-videos drawer
        // already are on this branch (Center + ConstrainedBox — see
        // instruction_videos_section.dart's own "Bug 3" fix, which wraps
        // its whole content column, header included, the same shape this
        // page's Column has), rather than only the scrollable body the way
        // help_center_page.dart does it. No effect on phones, where the
        // window is already narrower than the cap.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(l10n.clickV2Onboarding_title).large.semiBold),
                          BkIconButton.ghost(
                            key: const ValueKey('click-onboarding-close'),
                            icon: const Icon(LucideIcons.x),
                            label: context.i18n.close,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      Text(l10n.clickV2Onboarding_intro).small.muted,
                      Button.link(
                        onPressed: () => launchUrlString(_whyUrl),
                        trailing: const Icon(LucideIcons.externalLink, size: 14),
                        child: Text(l10n.clickV2Onboarding_whyLink),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                // The pager owns the full height between the header and the dot
                // indicator, hero included -- so a drag anywhere in that region
                // (contours included) swipes the pager, and short viewports can
                // scroll the whole page content, hero included. Each page now
                // carries its own fixed-state hero (see _option/_decision)
                // instead of one shared hero scrubbing above the PageView.
                Expanded(
                  child: PageView(
                    controller: _controller,
                    children: [
                      _option(
                        heroPage: 0,
                        fromPage: 0,
                        title: l10n.clickV2Onboarding_rightOnlyTitle,
                        pros: [l10n.clickV2Onboarding_rightOnlyPro1, l10n.clickV2Onboarding_rightOnlyPro2],
                        cons: [l10n.clickV2Onboarding_rightOnlyCon1],
                      ),
                      _option(
                        heroPage: 1,
                        fromPage: 1,
                        title: l10n.clickV2Onboarding_zwiftTitle,
                        pros: [l10n.clickV2Onboarding_zwiftPro1, l10n.clickV2Onboarding_zwiftPro2],
                        cons: [l10n.clickV2Onboarding_zwiftCon1, l10n.clickV2Onboarding_zwiftCon2],
                      ),
                      _decision(),
                    ],
                  ),
                ),
                Center(child: _dots()),
                const Gap(8),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Button.link(
                    onPressed: () => launchUrlString(_alternativesUrl),
                    trailing: const Icon(LucideIcons.externalLink, size: 14),
                    child: Text(l10n.clickV2Onboarding_alternativesLink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      key: const ValueKey('click-onboarding-dots'),
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (var i = 0; i < _pageCount; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_page.round() == i
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.mutedForeground.withValues(alpha: 0.4)),
            ),
          ),
      ],
    );
  }

  // The hero and the pros/cons list scroll together if they don't fit; the
  // swipe hint is a fixed sibling below so it's always reachable regardless
  // of how tall that content gets (long localized strings, a future badge,
  // etc.) — never itself scrolled out of view. This page is explanation-only:
  // the choice itself is made on the decision page (see _decision), so there
  // is no CTA here to tap by reflex without ever seeing the other option.
  Widget _option({
    required double heroPage,
    required int fromPage,
    required String title,
    required List<String> pros,
    required List<String> cons,
  }) {
    final rows = [...pros, ...cons];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A fixed per-page hero state rather than the shared
                // fractional _page value: feeding every page that same
                // scrubbing value would show two identical heroes sliding
                // past each other mid-swipe. Page 0 shows the left puck
                // alone; page 1 shows both.
                SizedBox(
                  height: 180,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ClickContours(page: heroPage),
                  ),
                ),
                const Gap(12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Text(title).large.semiBold,
                      for (var index = 0; index < rows.length; index++)
                        _row(rows[index], isPro: index < pros.length, index: index),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _swipeHint(fromPage: fromPage),
        ),
        const Gap(12),
      ],
    );
  }

  // Tapping advances the pager one page via the shared PageController. This
  // reverses an earlier "must not look tappable" call — the product owner
  // now wants it interactive — but it must still read as guidance rather
  // than the primary action: no fill/border beyond the ghost button's own
  // hover state, muted small text, trailing chevron. It never applies a
  // choice; pages 0 and 1 still carry no choice-applying control, which is
  // the whole point of the three-page structure.
  Widget _swipeHint({required int fromPage}) {
    final l10n = context.i18n;
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Button.ghost(
          key: ValueKey('click-onboarding-swipe-hint-$fromPage'),
          onPressed: () => _controller.animateToPage(
            fromPage + 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(l10n.clickV2Onboarding_swipeHint).small.muted,
              Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  // The third pager page: both options presented side by side so a choice
  // can't be made without having swiped past both explanations first. Both
  // buttons are Button.primary — neither option is "the" recommended one,
  // and styling either as secondary would reintroduce the default-choice
  // bias this restructuring exists to remove.
  Widget _decision() {
    final l10n = context.i18n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Both pucks live here — the right read for a page offering
                // both options, rather than either single-puck state. No
                // badge: the padlock explains the Zwift trade-off on page 1,
                // but here the choice is already laid out in the buttons
                // below, and the animated lock would just be noise.
                const SizedBox(
                  height: 180,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: ClickContours(page: 1, animate: false),
                  ),
                ),
                const Gap(12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text(l10n.clickV2Onboarding_decisionTitle).large.semiBold,
                      Text(l10n.clickV2Onboarding_decisionSubtitle).small.muted,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _staggered(
            0,
            _decisionOption(
              cta: l10n.clickV2Onboarding_rightOnlyCta,
              recap: l10n.clickV2Onboarding_rightOnlyRecap,
              onPressed: () => _choose(ClickV2Onboarding.chooseRightSideOnly),
            ),
          ),
        ),
        const Gap(12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _staggered(
            1,
            _decisionOption(
              cta: l10n.clickV2Onboarding_zwiftCta,
              recap: l10n.clickV2Onboarding_zwiftRecap,
              onPressed: () => _choose(ClickV2Onboarding.chooseUnlockWithZwift),
            ),
          ),
        ),
        const Gap(12),
      ],
    );
  }

  Widget _decisionOption({required String cta, required String recap, required VoidCallback onPressed}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        SizedBox(
          width: double.infinity,
          child: Button.primary(onPressed: _submitting ? null : onPressed, child: Text(cta)),
        ),
        Center(child: Text(recap).small.muted),
      ],
    );
  }

  Widget _row(String text, {required bool isPro, required int index}) {
    // Rows fade in and rise 8px, 60ms apart in order — enough to read as a
    // sequence without making the rider wait for it.
    return _staggered(
      index,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(
            isPro ? LucideIcons.circleCheck : LucideIcons.circleMinus,
            size: 16,
            color: isPro ? Colors.green : Theme.of(context).colorScheme.mutedForeground,
          ),
          Expanded(child: Text(text).small),
        ],
      ),
    );
  }

  // Shared staggered one-shot entrance, reused by the pro/con rows and the
  // decision page's two buttons so both read as the same kind of reveal.
  Widget _staggered(int index, Widget child) {
    final curve = _staggerCurves[index];
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }
}
