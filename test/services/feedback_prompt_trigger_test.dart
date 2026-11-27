// Coverage for `FeedbackPromptTrigger` — the once-per-launch bridge between
// `FeedbackPromptService.shouldShowPrompt` and the flow's `onShow` callback.
// `service.start()` runs higher in the widget tree than the page that owns a
// trigger, so `shouldShowPrompt` can already be `true` before a trigger
// attaches — a bare `addListener` would never fire for that case since the
// value doesn't change again. These tests pin `checkInitial()` covering that
// gap, the normal flip-to-eligible path, and the once-per-launch guard.
//
// Session-based redesign: unlike the old connection-COUNTING scheme (where
// `review_session_count` was inherited from an unrelated legacy feature and
// could already be over threshold with zero real usage behind it — "Bug
// 5a" required a same-launch connection before firing to guard against
// that), the new counter only advances on a genuinely qualifying session
// END (minimum duration AND a delivered command — see
// feedback_prompt_service_test.dart). There's nothing bogus left to guard
// against, so a cold start with nothing connected yet *this* launch, but
// enough qualifying sessions banked across previous launches, is
// intentionally eligible — see the second test below.
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Settings> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final settings = Settings();
  settings.prefs = await SharedPreferences.getInstance();
  return settings;
}

/// Seeds settings so a freshly-started service, with nothing connected, is
/// immediately eligible: past the successful-session threshold, past the
/// first-seen floor, no dismissal on file.
Future<void> _primeEligible(Settings settings, DateTime clock) async {
  await settings.setFeedbackSuccessfulSessionCount(FeedbackPromptService.successfulSessionThreshold);
  await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen * 2));
}

/// These tests are about the trigger's wiring, not the ownership gate: every
/// service here belongs to a rider who owns Base or Pro.
bool _owner() => true;

void main() {
  setUp(() {
    FeedbackPromptFlow.resetShownThisLaunchForTesting();
  });

  tearDown(() {
    FeedbackPromptFlow.resetShownThisLaunchForTesting();
  });

  test('checkInitial fires when already eligible before the trigger attaches', () async {
    final settings = await _settings();
    final clock = DateTime(2026, 1, 1);
    await _primeEligible(settings, clock);
    final service = FeedbackPromptService(
      settings: settings,
      trainerConnections: [ValueNotifier(false)],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service.start();
    expect(
      service.shouldShowPrompt.value,
      isTrue,
      reason: 'precondition: already eligible before the trigger attaches',
    );

    var shown = 0;
    final trigger = FeedbackPromptTrigger(service: service, onShow: () => shown++);

    expect(shown, 0, reason: 'attaching alone must not fire — only checkInitial() or a later flip does');

    trigger.checkInitial();

    expect(shown, 1);

    trigger.dispose();
    service.dispose();
  });

  test('checkInitial fires from sessions completed in a past launch, with nothing connected yet this launch', () async {
    final settings = await _settings();
    final clock = DateTime(2026, 1, 1);
    await _primeEligible(settings, clock);
    final service = FeedbackPromptService(
      settings: settings,
      trainerConnections: [ValueNotifier(false)],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service.start();
    expect(service.shouldShowPrompt.value, isTrue);

    var shown = 0;
    final trigger = FeedbackPromptTrigger(service: service, onShow: () => shown++);
    trigger.checkInitial();

    expect(shown, 1, reason: 'genuinely-earned past sessions are enough; no same-launch connection required');

    trigger.dispose();
    service.dispose();
  });

  test('fires on a later flip to eligible when not eligible at attach time', () async {
    final settings = await _settings();
    var clock = DateTime(2026, 1, 1);
    await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen * 2));
    await settings.setFeedbackSuccessfulSessionCount(FeedbackPromptService.successfulSessionThreshold - 1);
    final trainer = ValueNotifier(false);
    final service = FeedbackPromptService(
      settings: settings,
      trainerConnections: [trainer],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service.start();
    expect(service.shouldShowPrompt.value, isFalse);

    var shown = 0;
    final trigger = FeedbackPromptTrigger(service: service, onShow: () => shown++);
    trigger.checkInitial();
    expect(shown, 0, reason: 'checkInitial is a no-op while ineligible');

    // A full qualifying session: long enough, with a delivered command.
    trainer.value = true;
    await Future.value();
    service.recordCommandDelivered();
    clock = clock.add(FeedbackPromptService.minSessionDuration);
    trainer.value = false;
    await Future.value();

    expect(service.shouldShowPrompt.value, isTrue);
    expect(shown, 1);

    trigger.dispose();
    service.dispose();
  });

  test('never fires more than once per launch, across triggers and repeated flips', () async {
    final settings = await _settings();
    final clock = DateTime(2026, 1, 1);
    await _primeEligible(settings, clock);
    final service = FeedbackPromptService(
      settings: settings,
      trainerConnections: [ValueNotifier(false)],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service.start();
    expect(service.shouldShowPrompt.value, isTrue);

    var shown = 0;
    final trigger = FeedbackPromptTrigger(service: service, onShow: () => shown++);
    trigger.checkInitial();
    trigger.checkInitial();
    expect(shown, 1);

    // Dismissing and coming back eligible later in the same launch must not
    // re-fire — nor should a second trigger instance attached afterwards.
    await service.dismiss();
    await settings.setFeedbackSuccessfulSessionCount(
      FeedbackPromptService.successfulSessionThreshold + FeedbackPromptService.dismissalCooldownSessions,
    );
    await settings.setFeedbackPromptDismissedAt(clock.subtract(FeedbackPromptService.dismissalCooldownDuration));

    final service2 = FeedbackPromptService(
      settings: settings,
      trainerConnections: [ValueNotifier(false)],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service2.start();
    expect(service2.shouldShowPrompt.value, isTrue);

    var shownAgain = 0;
    final trigger2 = FeedbackPromptTrigger(service: service2, onShow: () => shownAgain++);
    trigger2.checkInitial();

    expect(shownAgain, 0, reason: 'shownThisLaunch guards across the whole app launch, not per-trigger');
    expect(shown, 1);

    trigger.dispose();
    trigger2.dispose();
    service.dispose();
    service2.dispose();
  });

  test('dispose stops the trigger from reacting to further changes', () async {
    final settings = await _settings();
    var clock = DateTime(2026, 1, 1);
    await settings.setFeedbackPromptFirstSeenAt(clock.subtract(FeedbackPromptService.minAgeSinceFirstSeen * 2));
    await settings.setFeedbackSuccessfulSessionCount(FeedbackPromptService.successfulSessionThreshold - 1);
    final trainer = ValueNotifier(false);
    final service = FeedbackPromptService(
      settings: settings,
      trainerConnections: [trainer],
      ownsPaidTier: _owner,
      now: () => clock,
    );
    service.start();

    var shown = 0;
    final trigger = FeedbackPromptTrigger(service: service, onShow: () => shown++);
    trigger.dispose();

    trainer.value = true;
    await Future.value();
    service.recordCommandDelivered();
    clock = clock.add(FeedbackPromptService.minSessionDuration);
    trainer.value = false;
    await Future.value();

    expect(service.shouldShowPrompt.value, isTrue);
    expect(shown, 0);

    service.dispose();
  });
}
