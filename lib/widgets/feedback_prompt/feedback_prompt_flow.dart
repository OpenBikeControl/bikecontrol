import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/utils/rate_app.dart';
import 'package:bike_control/widgets/feedback_prompt/confetti_burst.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_composer_step.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_thanks_step.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Steps of the feedback prompt flow. `gate` asks a plain thumbs up/down
/// sentiment question (no rating, no stars); `positive`/`negative` branch off
/// it. `positive` leads into `composer` (free-text) and `thanks`; `negative`
/// only ever offers "Get help" (out to the Help Center) or "Not now" — no
/// free-text complaint route lives here anymore, though `composer`/`thanks`
/// still support [FeedbackKind.complaint] for direct callers (tests, or a
/// future entry point).
enum FeedbackFlowStep { gate, positive, negative, composer, thanks }

/// Opens the feedback prompt flow as a bottom sheet — on every screen size,
/// matching the approved mockups (Bug 5b: this used to switch to a centered
/// dialog at `width >= 600`, which wasn't what the mockups showed).
///
/// Content width is capped on wide windows (`Center` + `ConstrainedBox`,
/// same treatment as `instruction_videos_section.dart`'s Bug 3 fix and
/// `home_sheets.dart`'s `_frame`) so the sheet isn't stretched full-width on
/// desktop, while staying full-width on phones.
Future<void> showFeedbackPromptFlow(
  BuildContext context, {
  required FeedbackPromptService service,
  FeedbackFlowStep initialStep = FeedbackFlowStep.gate,
}) async {
  await openDrawer(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FeedbackPromptFlow(
          service: service,
          initialStep: initialStep,
          onClose: () => closeDrawer(sheetContext),
        ),
      ),
    ),
  );
}

/// Renders the current step of the feedback prompt flow, cross-fading and
/// sliding between steps.
///
/// Pumped directly in widget tests without going through
/// [showFeedbackPromptFlow] — in that case there is no ambient dialog/drawer
/// route, so [onClose] is null and closing becomes a no-op instead of
/// crashing or popping an unrelated route.
class FeedbackPromptFlow extends StatefulWidget {
  final FeedbackPromptService service;
  final FeedbackFlowStep initialStep;
  final VoidCallback? onClose;

  /// Requests the native store rating prompt. Injectable so widget tests can
  /// substitute a spy instead of hitting the real store review API.
  final Future<void> Function() onRate;

  /// Talks to the `submit-feedback` edge function and the anonymous-session
  /// email link-up. Injectable so tests can substitute a fake instead of
  /// hitting real Supabase; defaults to a real instance for production use.
  final FeedbackSubmissionService? submissionService;

  /// Which (sentiment, kind) pair the composer/thanks steps were opened
  /// with, when [initialStep] is [FeedbackFlowStep.composer] or
  /// [FeedbackFlowStep.thanks] directly (tests, or a future direct-negative
  /// entry point). The suggest button on the positive step always opens
  /// (up, suggestion) regardless of these.
  final FeedbackSentiment initialSentiment;
  final FeedbackKind initialKind;

  const FeedbackPromptFlow({
    super.key,
    required this.service,
    this.initialStep = FeedbackFlowStep.gate,
    this.onClose,
    this.onRate = requestAppRating,
    this.submissionService,
    this.initialSentiment = FeedbackSentiment.up,
    this.initialKind = FeedbackKind.suggestion,
  });

  /// Guards against showing the gate more than once per app launch. Reset
  /// only by an app restart in production.
  static bool shownThisLaunch = false;

  /// Test-only escape hatch: resets [shownThisLaunch] so tests don't leak
  /// the once-per-launch guard into each other. Never call from app code.
  @visibleForTesting
  static void resetShownThisLaunchForTesting() => shownThisLaunch = false;

  @override
  State<FeedbackPromptFlow> createState() => _FeedbackPromptFlowState();
}

/// Wires [FeedbackPromptService.shouldShowPrompt] to a single, once-per-launch
/// [onShow] callback.
///
/// Extracted out of `OverviewPage` so the "already-eligible-at-attach" edge
/// case is independently testable: `service.start()` (called early, in
/// main.dart) can already have ended a qualifying session — e.g. one earned
/// in a previous launch, or one that finished before the page that owns
/// this trigger even builds — and set `shouldShowPrompt.value = true`
/// *before* this trigger attaches. A bare `addListener` only fires on a
/// value *change*, so that already-true state would otherwise never surface
/// the prompt — call [checkInitial] once right after construction to also
/// cover that case.
///
/// Unlike this trigger's once-per-launch guard, [FeedbackPromptService]'s
/// own eligibility does NOT require a qualifying session in THIS launch —
/// sessions genuinely completed in previous launches count too; see that
/// service's doc comment.
class FeedbackPromptTrigger {
  final FeedbackPromptService service;
  final VoidCallback onShow;

  FeedbackPromptTrigger({required this.service, required this.onShow}) {
    service.shouldShowPrompt.addListener(_onChanged);
  }

  void _onChanged() {
    if (!service.shouldShowPrompt.value) return;
    if (FeedbackPromptFlow.shownThisLaunch) return;
    FeedbackPromptFlow.shownThisLaunch = true;
    onShow();
  }

  /// Fires [onShow] immediately if [service] is already eligible. Safe to
  /// call unconditionally right after attaching — it's a no-op otherwise.
  void checkInitial() => _onChanged();

  void dispose() {
    service.shouldShowPrompt.removeListener(_onChanged);
  }
}

class _FeedbackPromptFlowState extends State<FeedbackPromptFlow> {
  late FeedbackFlowStep _step;
  late FeedbackSentiment _composerSentiment;
  late FeedbackKind _composerKind;

  /// Lazily built so steps that never touch Supabase (gate/positive/negative)
  /// don't force a real client to exist — tests for those steps never pass
  /// [FeedbackPromptFlow.submissionService] and don't have Supabase
  /// initialized at all.
  late final FeedbackSubmissionService _submissionService = widget.submissionService ?? FeedbackSubmissionService();

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _composerSentiment = widget.initialSentiment;
    _composerKind = widget.initialKind;
  }

  void _goTo(FeedbackFlowStep step) {
    if (!mounted) return;
    setState(() => _step = step);
  }

  /// Opens the composer for a specific (sentiment, kind) pair, remembered
  /// through to the thanks step (e.g. to decide whether "also rate" shows).
  void _goToComposer({required FeedbackSentiment sentiment, required FeedbackKind kind}) {
    if (!mounted) return;
    setState(() {
      _composerSentiment = sentiment;
      _composerKind = kind;
      _step = FeedbackFlowStep.composer;
    });
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onNotNow() async {
    await widget.service.dismiss();
    _close();
  }

  /// "Not now" from the negative step, unlike the gate's: the rider already
  /// said they're having trouble and chose to walk away from "Get help"
  /// rather than just not answering, so this counts as a terminal outcome —
  /// [markCompleted] like the other terminal branches (rate, suggest-submit,
  /// get-help), not [FeedbackPromptService.dismiss]'s 10-session snooze,
  /// which would just re-ask a rider who already told us something's wrong.
  Future<void> _onNegativeNotNow() async {
    await widget.service.markCompleted();
    _close();
  }

  /// "Get help" leaves the flow entirely for the Help Center's "Your setup"
  /// section. The flow may live inside a dialog or a bottom drawer, so the
  /// navigator that should receive the push is captured *before* closing —
  /// closing can tear down the context the flow was built with, and pushing
  /// afterwards on a defunct context would crash or land on the dismissed
  /// overlay instead of the app's own navigation stack.
  Future<void> _handleGetHelp() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await widget.service.markCompleted();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackPromptFlow.getHelp');
    }
    if (!mounted) return;
    _close();
    navigator.push(MaterialPageRoute(builder: (_) => const HelpCenterPage(focus: HelpCenterFocus.yourSetup)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('feedback-step-${_step.name}'),
        child: _buildStep(context),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case FeedbackFlowStep.gate:
        return _GateStep(
          onPositive: () => _goTo(FeedbackFlowStep.positive),
          onNegative: () => _goTo(FeedbackFlowStep.negative),
          onNotNow: _onNotNow,
        );
      case FeedbackFlowStep.positive:
        return _PositiveStep(
          service: widget.service,
          onRate: widget.onRate,
          onSuggest: () => _goToComposer(sentiment: FeedbackSentiment.up, kind: FeedbackKind.suggestion),
          onClosed: _close,
        );
      case FeedbackFlowStep.composer:
        return FeedbackComposerStep(
          service: widget.service,
          submissionService: _submissionService,
          sentiment: _composerSentiment,
          kind: _composerKind,
          onSubmitted: () => _goTo(FeedbackFlowStep.thanks),
        );
      case FeedbackFlowStep.thanks:
        return FeedbackThanksStep(
          submissionService: _submissionService,
          kind: _composerKind,
          onRate: widget.onRate,
          onClosed: _close,
        );
      case FeedbackFlowStep.negative:
        return _NegativeStep(
          onGetHelp: _handleGetHelp,
          onNotNow: _onNegativeNotNow,
        );
    }
  }
}

class _GateStep extends StatelessWidget {
  final VoidCallback onPositive;
  final VoidCallback onNegative;
  final Future<void> Function() onNotNow;

  const _GateStep({
    required this.onPositive,
    required this.onNegative,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.feedbackPromptTitle, textAlign: TextAlign.center).semiBold,
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Button.outline(
                key: const ValueKey('feedback-thumbs-up'),
                style: const ButtonStyle.outline(size: ButtonSize.large),
                onPressed: onPositive,
                child: const Icon(LucideIcons.thumbsUp, size: 28),
              ),
              Button.outline(
                key: const ValueKey('feedback-thumbs-down'),
                style: const ButtonStyle.outline(size: ButtonSize.large),
                onPressed: onNegative,
                child: const Icon(LucideIcons.thumbsDown, size: 28),
              ),
            ],
          ),
          const Gap(12),
          Center(
            child: Button.ghost(
              key: const ValueKey('feedback-not-now'),
              onPressed: () => onNotNow(),
              child: Text(l10n.feedbackPromptNotNow),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbs-up branch of the gate: offers a native store rating or a written
/// suggestion, celebrating with a one-shot confetti burst behind the
/// content.
class _PositiveStep extends StatefulWidget {
  final FeedbackPromptService service;
  final Future<void> Function() onRate;
  final VoidCallback onSuggest;
  final VoidCallback onClosed;

  const _PositiveStep({
    required this.service,
    required this.onRate,
    required this.onSuggest,
    required this.onClosed,
  });

  @override
  State<_PositiveStep> createState() => _PositiveStepState();
}

class _PositiveStepState extends State<_PositiveStep> {
  bool _rating = false;

  Future<void> _handleRate() async {
    if (_rating) return;
    setState(() => _rating = true);
    try {
      await widget.onRate();
      await widget.service.markCompleted();
      if (mounted) widget.onClosed();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackPromptFlow.rate');
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: ConfettiBurst()),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.feedbackPositiveTitle, textAlign: TextAlign.center).semiBold,
              const Gap(20),
              PrimaryButton(
                key: const ValueKey('feedback-rate'),
                onPressed: _rating ? null : _handleRate,
                child: Text(l10n.feedbackRateButton),
              ),
              const Gap(12),
              SecondaryButton(
                key: const ValueKey('feedback-suggest'),
                onPressed: widget.onSuggest,
                child: Text(l10n.feedbackSuggestButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thumbs-down branch of the gate: offers a single direct line to the Help
/// Center, or dismissal — never mentions the store, since a bad experience
/// isn't the moment to ask for a rating. There is no free-text complaint
/// route here: "Get help" (guides for the rider's exact setup, known
/// issues, and support, all in one place) is the one action that matters.
class _NegativeStep extends StatelessWidget {
  final VoidCallback onGetHelp;
  final Future<void> Function() onNotNow;

  const _NegativeStep({required this.onGetHelp, required this.onNotNow});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.feedbackNegativeTitle, textAlign: TextAlign.center).semiBold,
          const Gap(8),
          Text(l10n.feedbackNegativeBody, textAlign: TextAlign.center).muted,
          const Gap(20),
          PrimaryButton(
            key: const ValueKey('feedback-get-help'),
            onPressed: onGetHelp,
            child: Text(l10n.feedbackGetHelpButton),
          ),
          const Gap(12),
          Center(
            child: Button.ghost(
              key: const ValueKey('feedback-negative-not-now'),
              onPressed: () => onNotNow(),
              child: Text(l10n.feedbackPromptNotNow),
            ),
          ),
        ],
      ),
    );
  }
}
