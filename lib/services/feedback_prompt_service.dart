import 'dart:async';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';

/// Decides when the "how's it going" feedback bottom sheet is allowed to
/// appear.
///
/// ## What counts as a session
/// A session starts the moment any [trainerConnections] entry flips to
/// connected, and ends only once every one of them is disconnected again.
/// By the time a session ends, it counts toward [successfulSessionThreshold]
/// only if BOTH hold:
///  - it lasted at least [minSessionDuration] — a dropped BLE link or a
///    rider backing out of setup isn't real usage, and
///  - at least one command was actually delivered to the trainer app during
///    it (see [recordCommandDelivered]) — being connected isn't the same as
///    having pressed a button.
///
/// The counter is incremented — and [shouldShowPrompt] re-checked — on
/// session END, never on session START. That ordering is also what keeps the
/// rider from ever seeing the sheet mid-ride: [_isEligible] refuses while a
/// session is active, so [shouldShowPrompt] is forced back to `false` the
/// instant a session starts and only re-evaluated once every trainer has
/// disconnected. Whether the overview screen happens to be on screen at that
/// moment is the caller's job, not this service's — see
/// `FeedbackPromptTrigger` / `OverviewPage`.
///
/// ## Owners only
/// The sheet is only ever shown to a rider who owns a paid tier — Base
/// bought outright, or an active Pro entitlement (see [ownsPaidTier]). It is
/// never shown to a free rider, whether their trial is still running or long
/// since expired. That subsumes the old trial-only gate this parameter
/// replaced: somebody on trial hasn't bought anything, so they fail the same
/// check. [ownsPaidTier] has no default on purpose — every construction site
/// has to say which riders it speaks for, so the gate can't be lost by
/// omission.
///
/// ## Rebase from the old review banner
/// This replaces a connection-COUNTING scheme that bumped a counter on the
/// first trainer connection of a launch and fired as soon as it (and a few
/// other gates) crossed a threshold — including while the rider was still
/// connecting, not after any real usage. That old counter,
/// `review_session_count`, pre-dates this feature entirely (the old
/// star-rating banner used the same key), so existing installs were already
/// far past any reasonable threshold the moment this shipped.
///
/// [Settings.getFeedbackSuccessfulSessionCount] is a brand new key that
/// starts at 0 for every install, existing users included — nothing in this
/// file reads `review_session_count` or
/// `review_dismissed_at_session_count` again. `review_completed` is the one
/// legacy signal still honoured ([markCompleted] hard-stops on it): someone
/// who already rated the app must never be asked again, regardless of how
/// that flag got set. `review_dismissed_at_session_count` — the old snooze
/// marker — is deliberately left alone: it was measured against the old
/// counter's scale (comparing it against the new counter would be
/// meaningless) and it never carried a timestamp, so it can't answer the
/// new dismissal cooldown's day-based arm either. A rider who dismissed the
/// old banner gets the same clean ramp as anyone else under the new rules.
class FeedbackPromptService {
  /// Successful sessions needed before the prompt is eligible at all.
  static const int successfulSessionThreshold = 6;

  /// A session must last at least this long to count.
  static const Duration minSessionDuration = Duration(minutes: 5);

  /// Floor on how soon we'll ask, measured from the first time this
  /// session-based logic ever ran on this device (see
  /// [Settings.getFeedbackPromptFirstSeenAt]) — gives a rider a chance to
  /// form an opinion even if they rack up qualifying sessions unusually
  /// fast.
  static const Duration minAgeSinceFirstSeen = Duration(days: 3);

  /// After "Not now", require this many MORE successful sessions...
  static const int dismissalCooldownSessions = 10;

  /// ...AND at least this long since the dismissal. Both must hold before
  /// the sheet is eligible again.
  static const Duration dismissalCooldownDuration = Duration(days: 14);

  final Settings settings;
  final List<ValueListenable<bool>> trainerConnections;
  /// Whether the rider owns Base or Pro. Read fresh on every eligibility
  /// check rather than captured once, so a purchase mid-launch takes effect
  /// at the next re-check.
  final bool Function() ownsPaidTier;

  /// Injected clock so tests can control elapsed time deterministically.
  /// Never call `DateTime.now()` directly in this file — go through [now].
  final DateTime Function() now;

  final ValueNotifier<bool> shouldShowPrompt = ValueNotifier(false);

  bool _sessionActive = false;
  DateTime? _sessionStartedAt;
  bool _sessionCommandDelivered = false;

  final List<VoidCallback> _disposers = [];

  FeedbackPromptService({
    required this.settings,
    required this.trainerConnections,
    required this.ownsPaidTier,
    this.now = DateTime.now,
  });

  void start() {
    for (final notifier in trainerConnections) {
      void listener() => _onConnectionsChanged();
      notifier.addListener(listener);
      _disposers.add(() => notifier.removeListener(listener));
    }
    // Baseline the aggregate without treating "already connected before
    // start() ran" as a session we timed — we don't know how long it had
    // already been connected, so that span simply never counts (see the
    // null-startedAt guard in `_endSession`).
    _sessionActive = _anyConnected;
    _recordFirstSeenIfNeeded();
    _refreshBannerState();
  }

  bool get _anyConnected => trainerConnections.any((connection) => connection.value);

  void _recordFirstSeenIfNeeded() {
    if (settings.getFeedbackPromptFirstSeenAt() != null) return;
    unawaited(_persistFirstSeen());
  }

  Future<void> _persistFirstSeen() async {
    try {
      await settings.setFeedbackPromptFirstSeenAt(now());
      _refreshBannerState();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackPromptService.recordFirstSeen');
    }
  }

  void _onConnectionsChanged() {
    final connected = _anyConnected;
    if (connected == _sessionActive) return;
    if (connected) {
      _sessionActive = true;
      _sessionStartedAt = now();
      _sessionCommandDelivered = false;
      _refreshBannerState(); // hide immediately: a session is now active
      return;
    }
    _endSession();
  }

  void _endSession() {
    final startedAt = _sessionStartedAt;
    final delivered = _sessionCommandDelivered;
    _sessionActive = false;
    _sessionStartedAt = null;
    _sessionCommandDelivered = false;

    final qualifies = startedAt != null && delivered && now().difference(startedAt) >= minSessionDuration;
    if (!qualifies) {
      _refreshBannerState();
      return;
    }
    unawaited(_persistSuccessfulSession());
  }

  Future<void> _persistSuccessfulSession() async {
    try {
      final next = settings.getFeedbackSuccessfulSessionCount() + 1;
      await settings.setFeedbackSuccessfulSessionCount(next);
      _refreshBannerState();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackPromptService.recordSuccessfulSession');
    }
  }

  /// Called from `BaseDevice` whenever a physical button press resolves to
  /// `Success` — the one signal that a command was actually delivered, not
  /// just that a trainer happened to be connected. A no-op outside an
  /// active session.
  void recordCommandDelivered() {
    if (!_sessionActive) return;
    _sessionCommandDelivered = true;
  }

  void _refreshBannerState() {
    shouldShowPrompt.value = _isEligible();
  }

  bool _isEligible() {
    // Never mid-ride. The trigger/OverviewPage layer adds "is the overview
    // on screen" on top of this.
    if (_sessionActive) return false;
    if (!ownsPaidTier()) return false;
    if (settings.getReviewCompleted()) return false;

    final firstSeenAt = settings.getFeedbackPromptFirstSeenAt();
    if (firstSeenAt == null) return false; // start() hasn't recorded it yet
    if (now().difference(firstSeenAt) < minAgeSinceFirstSeen) return false;

    final count = settings.getFeedbackSuccessfulSessionCount();
    if (count < successfulSessionThreshold) return false;

    final dismissedAtCount = settings.getFeedbackPromptDismissedAtSessionCount();
    final dismissedAt = settings.getFeedbackPromptDismissedAt();
    if (dismissedAtCount != null && dismissedAt != null) {
      final sessionsSinceDismissal = count - dismissedAtCount;
      if (sessionsSinceDismissal < dismissalCooldownSessions) return false;
      if (now().difference(dismissedAt) < dismissalCooldownDuration) return false;
    }

    return true;
  }

  Future<void> markCompleted() async {
    await settings.setReviewCompleted(true);
    _refreshBannerState();
  }

  Future<void> dismiss() async {
    await settings.setFeedbackPromptDismissedAtSessionCount(settings.getFeedbackSuccessfulSessionCount());
    await settings.setFeedbackPromptDismissedAt(now());
    _refreshBannerState();
  }

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
    shouldShowPrompt.dispose();
  }
}
