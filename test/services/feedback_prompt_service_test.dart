// Coverage for the session-based redesign of FeedbackPromptService. A
// "session" spans from the first trainer connection going live to the last
// one dropping; it only counts toward `successfulSessionThreshold` if it
// lasted at least `minSessionDuration` AND at least one command was
// delivered during it (`recordCommandDelivered`, the hook `BaseDevice`
// calls on a `Success` `ActionResult`). The counter advances — and
// `shouldShowPrompt` is re-checked — on session END, never on START, which
// is also what guarantees the sheet can never become eligible mid-ride.
//
// This replaces a connection-COUNTING scheme keyed off `review_session_count`
// — a counter inherited from the old star-rating banner, already far past
// threshold for existing installs with zero real usage behind it. The new
// counter (`getFeedbackSuccessfulSessionCount`) is a brand new key, rebased
// to 0 for everyone; nothing here reads the legacy counter or its dismissal
// marker (`review_dismissed_at_session_count`) — see
// `FeedbackPromptService`'s doc comment for the full rationale.
//
// The sheet is also owners-only: it may only ever reach a rider who bought
// Base or holds Pro (`ownsPaidTier`). Free riders — on trial or past it —
// are never asked, so the harness below defaults to an owner and the
// ownership tests opt out explicitly.
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default for the test harness: a rider who owns Base or Pro, i.e. the only
/// kind of rider the prompt may reach at all. Tests that care about the
/// ownership gate pass their own.
bool _owner() => true;

void main() {
  late Settings settings;
  late DateTime clock;
  DateTime now() => clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 1, 1);
  });

  /// Seeds every gate except the successful-session counter: first-seen
  /// recorded well past `minAgeSinceFirstSeen`, no dismissal on file, not on
  /// trial, not yet reviewed. Lets each test isolate exactly the one thing
  /// it's checking.
  Future<void> primeGatesExceptCount({required int successfulSessions}) async {
    await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen * 2));
    await settings.setFeedbackSuccessfulSessionCount(successfulSessions);
  }

  FeedbackPromptService makeService(
    List<ValueNotifier<bool>> trainers, {
    bool Function() ownsPaidTier = _owner,
  }) {
    return FeedbackPromptService(
      settings: settings,
      trainerConnections: trainers,
      ownsPaidTier: ownsPaidTier,
      now: now,
    );
  }

  group('session counting', () {
    test('a short session does not count even with a delivered command', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final trainer = ValueNotifier(false);
      final service = makeService([trainer]);
      service.start();

      trainer.value = true;
      await Future.value();
      service.recordCommandDelivered();
      clock = clock.add(FeedbackPromptService.minSessionDuration - const Duration(seconds: 1));
      trainer.value = false;
      await Future.value();

      expect(
        settings.getFeedbackSuccessfulSessionCount(),
        FeedbackPromptService.successfulSessionThreshold - 1,
        reason: 'too short to count',
      );
      expect(service.shouldShowPrompt.value, isFalse);

      service.dispose();
    });

    test('a long session with no delivered command does not count', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final trainer = ValueNotifier(false);
      final service = makeService([trainer]);
      service.start();

      trainer.value = true;
      await Future.value();
      clock = clock.add(FeedbackPromptService.minSessionDuration * 2);
      trainer.value = false;
      await Future.value();

      expect(
        settings.getFeedbackSuccessfulSessionCount(),
        FeedbackPromptService.successfulSessionThreshold - 1,
        reason: 'long enough, but nothing was ever delivered',
      );
      expect(service.shouldShowPrompt.value, isFalse);

      service.dispose();
    });

    test('a long session with a delivered command counts on END, not on start', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final trainer = ValueNotifier(false);
      final service = makeService([trainer]);
      service.start();

      trainer.value = true;
      await Future.value();
      service.recordCommandDelivered();
      clock = clock.add(FeedbackPromptService.minSessionDuration);

      // Still connected: every other gate is already satisfied, but it must
      // not have counted yet and must not be showable.
      expect(settings.getFeedbackSuccessfulSessionCount(), FeedbackPromptService.successfulSessionThreshold - 1);
      expect(service.shouldShowPrompt.value, isFalse);

      trainer.value = false;
      await Future.value();

      expect(settings.getFeedbackSuccessfulSessionCount(), FeedbackPromptService.successfulSessionThreshold);
      expect(service.shouldShowPrompt.value, isTrue);

      service.dispose();
    });

    test('the sheet never becomes eligible while a session is active, even once already over threshold', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      final trainer = ValueNotifier(false);
      final service = makeService([trainer]);
      service.start();
      expect(service.shouldShowPrompt.value, isTrue, reason: 'precondition: eligible before this ride starts');

      trainer.value = true;
      await Future.value();

      expect(service.shouldShowPrompt.value, isFalse, reason: 'must hide the instant a new session starts');

      service.dispose();
    });

    test('a session spanning multiple connections only ends once ALL are disconnected', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final trainerA = ValueNotifier(false);
      final trainerB = ValueNotifier(false);
      final service = makeService([trainerA, trainerB]);
      service.start();

      trainerA.value = true;
      await Future.value();
      trainerB.value = true;
      await Future.value();
      service.recordCommandDelivered();
      clock = clock.add(FeedbackPromptService.minSessionDuration);

      trainerA.value = false; // one drops, the other is still up
      await Future.value();
      expect(settings.getFeedbackSuccessfulSessionCount(), FeedbackPromptService.successfulSessionThreshold - 1);
      expect(service.shouldShowPrompt.value, isFalse);

      trainerB.value = false; // now all are down: the session actually ends
      await Future.value();
      expect(settings.getFeedbackSuccessfulSessionCount(), FeedbackPromptService.successfulSessionThreshold);

      service.dispose();
    });

    test('a connection already up before start() is never counted (no known start time)', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final trainer = ValueNotifier(true);
      final service = makeService([trainer]);
      service.start();

      service.recordCommandDelivered();
      clock = clock.add(FeedbackPromptService.minSessionDuration * 2);
      trainer.value = false;
      await Future.value();

      expect(
        settings.getFeedbackSuccessfulSessionCount(),
        FeedbackPromptService.successfulSessionThreshold - 1,
        reason: 'we never observed when this connection actually started',
      );

      service.dispose();
    });
  });

  group('gates', () {
    test('below threshold: not eligible', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      service.dispose();
    });

    test('at threshold with every other gate satisfied: eligible', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isTrue);
      service.dispose();
    });

    test('first-seen floor: not eligible before minAgeSinceFirstSeen has passed', () async {
      await settings.setFeedbackSuccessfulSessionCount(FeedbackPromptService.successfulSessionThreshold);
      await settings.setFeedbackPromptFirstSeenAt(clock); // recorded "just now"
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      service.dispose();
    });

    test('first-seen floor: eligible once minAgeSinceFirstSeen has passed', () async {
      await settings.setFeedbackSuccessfulSessionCount(FeedbackPromptService.successfulSessionThreshold);
      await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen));
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isTrue);
      service.dispose();
    });

    test('first run records a first-seen timestamp so the floor starts counting immediately', () async {
      expect(settings.getFeedbackPromptFirstSeenAt(), isNull);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      await Future.value();
      expect(settings.getFeedbackPromptFirstSeenAt()!.isAtSameMomentAs(clock), isTrue);
      service.dispose();
    });

    test('ownership gate: not eligible for a rider who owns neither Base nor Pro', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      final service = makeService([ValueNotifier(false)], ownsPaidTier: () => false);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      service.dispose();
    });

    test('ownership gate: a trial rider is not an owner, and an expired trial does not make one', () async {
      // Both ends of the unpaid lifecycle resolve to the same answer: the
      // gate asks "did they buy Base or Pro", not "is the trial over". A
      // rider who ran the trial out and fell back to the daily command cap
      // stays excluded for as long as they never buy.
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold * 3);
      final duringTrial = makeService([ValueNotifier(false)], ownsPaidTier: () => false);
      duringTrial.start();
      expect(duringTrial.shouldShowPrompt.value, isFalse, reason: 'still on trial: nothing bought yet');
      duringTrial.dispose();

      final afterTrial = makeService([ValueNotifier(false)], ownsPaidTier: () => false);
      afterTrial.start();
      expect(afterTrial.shouldShowPrompt.value, isFalse, reason: 'trial expired without a purchase: still not an owner');
      afterTrial.dispose();
    });

    test('ownership gate: becomes eligible the moment the rider buys', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      var owns = false;
      final trainer = ValueNotifier(false);
      final service = makeService([trainer], ownsPaidTier: () => owns);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);

      owns = true;
      // Nothing changed on the trainer side, so nothing re-triggers a
      // refresh by itself — flip a connection like a real purchase +
      // reconnect would, ending a (too-short, here) session to force a
      // re-check. This exercises the predicate being re-read, not a new
      // qualifying session.
      trainer.value = true;
      await Future.value();
      trainer.value = false;
      await Future.value();

      expect(service.shouldShowPrompt.value, isTrue);
      service.dispose();
    });

    test('ownership gate: an owner who never rides is still held back by the session gates', () async {
      // The gate only ever subtracts. Owning Base or Pro is a precondition,
      // not a shortcut past the usage threshold.
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold - 1);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      service.dispose();
    });

    test('review_completed is a hard stop regardless of every other gate', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      await settings.setReviewCompleted(true);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      service.dispose();
    });

    test('markCompleted hides the prompt forever, across service instances', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isTrue);

      await service.markCompleted();
      expect(service.shouldShowPrompt.value, isFalse);
      expect(settings.getReviewCompleted(), isTrue);
      service.dispose();

      final next = makeService([ValueNotifier(false)]);
      next.start();
      expect(next.shouldShowPrompt.value, isFalse);
      next.dispose();
    });

    test('a stale legacy review_session_count of 999 does not make a fresh user eligible', () async {
      await settings.setReviewSessionCount(999);
      await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen * 2));
      // Deliberately leave the NEW counter at its default (0) — only the
      // legacy, unrelated key is inflated.
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isFalse);
      expect(settings.getFeedbackSuccessfulSessionCount(), 0);
      service.dispose();
    });
  });

  group('dismissal cooldown', () {
    test('dismiss() blocks until BOTH the session-count and day cooldowns clear', () async {
      await primeGatesExceptCount(successfulSessions: FeedbackPromptService.successfulSessionThreshold);
      final service = makeService([ValueNotifier(false)]);
      service.start();
      expect(service.shouldShowPrompt.value, isTrue);

      await service.dismiss();
      expect(service.shouldShowPrompt.value, isFalse);
      expect(settings.getFeedbackPromptDismissedAtSessionCount(), FeedbackPromptService.successfulSessionThreshold);
      expect(settings.getFeedbackPromptDismissedAt()!.isAtSameMomentAs(clock), isTrue);

      // Enough successful sessions, but not enough days yet: still blocked.
      await settings.setFeedbackSuccessfulSessionCount(
        FeedbackPromptService.successfulSessionThreshold + FeedbackPromptService.dismissalCooldownSessions,
      );
      await settings.setFeedbackPromptDismissedAt(
        clock.subtract(FeedbackPromptService.dismissalCooldownDuration - const Duration(days: 1)),
      );
      final sessionsOkDaysShort = makeService([ValueNotifier(false)]);
      sessionsOkDaysShort.start();
      expect(sessionsOkDaysShort.shouldShowPrompt.value, isFalse);
      sessionsOkDaysShort.dispose();

      // Enough days, but not enough further sessions: still blocked.
      await settings.setFeedbackSuccessfulSessionCount(
        FeedbackPromptService.successfulSessionThreshold + FeedbackPromptService.dismissalCooldownSessions - 1,
      );
      await settings.setFeedbackPromptDismissedAt(clock.subtract(FeedbackPromptService.dismissalCooldownDuration));
      final daysOkSessionsShort = makeService([ValueNotifier(false)]);
      daysOkSessionsShort.start();
      expect(daysOkSessionsShort.shouldShowPrompt.value, isFalse);
      daysOkSessionsShort.dispose();

      // Both satisfied: eligible again.
      await settings.setFeedbackSuccessfulSessionCount(
        FeedbackPromptService.successfulSessionThreshold + FeedbackPromptService.dismissalCooldownSessions,
      );
      final reshown = makeService([ValueNotifier(false)]);
      reshown.start();
      expect(reshown.shouldShowPrompt.value, isTrue);
      reshown.dispose();

      service.dispose();
    });
  });
}
