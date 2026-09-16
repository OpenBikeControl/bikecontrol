import 'package:bike_control/pages/home/chain_state.dart';
import 'package:flutter_test/flutter_test.dart';

ChainLink link({
  required String id,
  ChainLinkKey key = ChainLinkKey.controller,
  LinkStatus status = LinkStatus.ready,
  bool optional = false,
  List<bool> steps = const [true],
}) {
  return ChainLink(
    key: key,
    id: id,
    status: status,
    title: id,
    optional: optional,
    steps: [
      for (final (i, done) in steps.indexed)
        SetupStep(id: SetupStepId.values[i % SetupStepId.values.length], done: done),
    ],
  );
}

void main() {
  group('ChainLinkKey', () {
    // The sensors link takes the trainer's slot in sensors-only mode.
    // Asserting it is in [ChainLinkKey.values] pins down the enum member;
    // the real exhaustiveness guard is that every `switch (ChainLinkKey ...)`
    // in the widget layer (chain_labels.dart, home_page.dart) fails to
    // compile without a `sensors` arm, which this file's own import already
    // exercises.
    test('includes sensors, between trainer and app', () {
      expect(ChainLinkKey.values, [
        ChainLinkKey.controller,
        ChainLinkKey.trainer,
        ChainLinkKey.sensors,
        ChainLinkKey.app,
      ]);
    });
  });

  group('ChainLink step counting', () {
    test('counts done and remaining steps', () {
      final l = link(id: 'a', steps: [true, false, false]);
      expect(l.doneSteps, 1);
      expect(l.remainingSteps, 2);
    });

    test('active step is the first unfinished one', () {
      final l = link(id: 'a', steps: [true, false, false]);
      expect(l.activeStepIndex, 1);
      expect(l.activeStep, isNotNull);
      expect(l.activeStep!.done, isFalse);
    });

    test('a complete checklist has no active step', () {
      final l = link(id: 'a', steps: [true, true]);
      expect(l.activeStepIndex, isNull);
      expect(l.activeStep, isNull);
      expect(l.remainingSteps, 0);
    });

    test('an empty checklist has no active step and does not crash', () {
      final l = link(id: 'a', steps: []);
      expect(l.activeStepIndex, isNull);
      expect(l.doneSteps, 0);
      expect(l.remainingSteps, 0);
      expect(l.pendingSteps, isEmpty);
    });

    test('a done step later in the list does not become active', () {
      final l = link(id: 'a', steps: [false, true, false]);
      expect(l.activeStepIndex, 0);
    });

    // An optional step is an offer. Counting it would have the banner announce
    // "1 step left" at a rider who is completely set up and simply doesn't want
    // the gear overlay.
    test('an outstanding optional step is not counted as remaining work', () {
      final l = ChainLink(
        key: ChainLinkKey.trainer,
        id: 't',
        status: LinkStatus.ready,
        title: 't',
        steps: const [
          SetupStep(id: SetupStepId.trainerPaired, done: true),
          SetupStep(id: SetupStepId.trainerGearOverlay, done: false, optional: true),
        ],
      );
      expect(l.remainingSteps, 0);
      expect(l.doneSteps, 1);
      // It is still on the card — that is the whole point of it.
      expect(l.pendingSteps.map((s) => s.id), [SetupStepId.trainerGearOverlay]);
      expect(l.activeStep?.id, SetupStepId.trainerGearOverlay);
    });
  });

  group('ChainLink.isBlocking', () {
    test('ready never blocks', () {
      expect(link(id: 'a', status: LinkStatus.ready).isBlocking, isFalse);
    });

    test('attention, problem and off all block a required link', () {
      for (final status in [LinkStatus.attention, LinkStatus.problem, LinkStatus.off]) {
        expect(link(id: 'a', status: status).isBlocking, isTrue, reason: status.name);
      }
    });

    test('an optional link at rest is not a blocker', () {
      expect(link(id: 't', status: LinkStatus.off, optional: true).isBlocking, isFalse);
    });

    test('an optional link that broke still blocks', () {
      expect(link(id: 't', status: LinkStatus.problem, optional: true).isBlocking, isTrue);
      expect(link(id: 't', status: LinkStatus.attention, optional: true).isBlocking, isTrue);
    });
  });

  group('pendingSteps', () {
    test('lists only what is still to do, in order', () {
      final l = link(id: 'a', steps: [true, false, true, false]);
      expect(l.pendingSteps, hasLength(2));
      expect(l.pendingSteps.every((s) => !s.done), isTrue);
    });

    test('is empty once everything is done — a finished card has nothing to show', () {
      expect(link(id: 'a', steps: [true, true]).pendingSteps, isEmpty);
    });

    test('the first pending step is the active one', () {
      final l = link(id: 'a', steps: [true, false, false]);
      expect(l.pendingSteps.first, same(l.activeStep));
    });
  });

  group('deriveBanner', () {
    test('everything ready gives a calm banner with no action', () {
      final banner = deriveBanner([
        link(id: 'c', status: LinkStatus.ready),
        link(id: 'trainer', status: LinkStatus.off, optional: true),
        link(id: 'app', status: LinkStatus.ready),
      ]);
      expect(banner.kind, ChainBannerKind.ready);
      expect(banner.status, LinkStatus.ready);
      expect(banner.stepsLeft, 0);
      expect(banner.hasAction, isFalse);
      expect(banner.targetLinkId, isNull);
    });

    test('an optional link at rest does not spoil "ready to ride"', () {
      final banner = deriveBanner([
        link(id: 'c', status: LinkStatus.ready),
        link(id: 'trainer', status: LinkStatus.off, optional: true, steps: [false, false]),
      ]);
      expect(banner.kind, ChainBannerKind.ready);
      expect(banner.stepsLeft, 0);
    });

    test('counts outstanding steps across every blocking link', () {
      final banner = deriveBanner([
        link(id: 'c', status: LinkStatus.attention, steps: [true, false, false]),
        link(id: 'app', status: LinkStatus.attention, steps: [true, false]),
      ]);
      expect(banner.kind, ChainBannerKind.pending);
      expect(banner.stepsLeft, 3);
    });

    test('ignores steps left on non-blocking links', () {
      // A ready card with a stale unfinished step must not inflate the count.
      final banner = deriveBanner([
        link(id: 'c', status: LinkStatus.ready, steps: [true, false]),
        link(id: 'app', status: LinkStatus.attention, steps: [false]),
      ]);
      expect(banner.stepsLeft, 1);
    });

    test('pending targets the first blocking link in render order', () {
      final banner = deriveBanner([
        link(id: 'c', status: LinkStatus.ready),
        link(id: 'trainer', status: LinkStatus.attention, steps: [false]),
        link(id: 'app', status: LinkStatus.attention, steps: [false]),
      ]);
      expect(banner.targetLinkId, 'trainer');
    });

    test('a broken link outranks an unfinished one wherever it sits', () {
      final banner = deriveBanner([
        link(id: 'app', status: LinkStatus.attention, steps: [false]),
        link(id: 'c', status: LinkStatus.problem, steps: [true, false]),
      ]);
      expect(banner.kind, ChainBannerKind.broken);
      expect(banner.status, LinkStatus.problem);
      expect(banner.targetLinkId, 'c');
      // The count still covers everything outstanding, not just the break.
      expect(banner.stepsLeft, 2);
    });

    test('the first broken link wins when several broke', () {
      final banner = deriveBanner([
        link(id: 'c1', status: LinkStatus.problem, steps: [false]),
        link(id: 'c2', status: LinkStatus.problem, steps: [false]),
      ]);
      expect(banner.targetLinkId, 'c1');
    });

    test('outstanding keys are distinct and in render order', () {
      final banner = deriveBanner([
        link(id: 'c1', key: ChainLinkKey.controller, status: LinkStatus.attention, steps: [false]),
        link(id: 'c2', key: ChainLinkKey.controller, status: LinkStatus.attention, steps: [false]),
        link(id: 'app', key: ChainLinkKey.app, status: LinkStatus.attention, steps: [false]),
      ]);
      expect(banner.outstandingKeys, [ChainLinkKey.controller, ChainLinkKey.app]);
    });

    test('an empty chain is treated as ready rather than crashing', () {
      final banner = deriveBanner([]);
      expect(banner.kind, ChainBannerKind.ready);
      expect(banner.hasAction, isFalse);
    });

    test('the banner target is always a link that is actually in the chain', () {
      final links = [
        link(id: 'c', status: LinkStatus.ready),
        link(id: 'app', status: LinkStatus.attention, steps: [false]),
      ];
      final banner = deriveBanner(links);
      expect(links.map((l) => l.id), contains(banner.targetLinkId));
    });

    // The trainer app's pairing screen has two BikeControl tiles. When the
    // trainer one is already done and the controller one is all that is left,
    // the banner can say exactly that instead of "finish the Trainer app
    // card" — but only when it really is the one thing left across the chain.
    group('the sole outstanding step', () {
      ChainLink appLink(List<SetupStep> steps) => ChainLink(
        key: ChainLinkKey.app,
        id: 'app',
        status: LinkStatus.attention,
        title: 'MyWhoosh',
        steps: steps,
      );

      const controllerLinkMissing = SetupStep(
        id: SetupStepId.appConnected,
        done: false,
        variant: SetupStepVariant.controllerLinkMissing,
      );

      test('is handed to the banner when exactly one required step is outstanding', () {
        final banner = deriveBanner([
          link(id: 'c', status: LinkStatus.ready),
          link(id: 'trainer', key: ChainLinkKey.trainer, optional: true),
          appLink(const [
            SetupStep(id: SetupStepId.appSelected, done: true),
            SetupStep(id: SetupStepId.appConnectionMethod, done: true),
            controllerLinkMissing,
          ]),
        ]);
        expect(banner.kind, ChainBannerKind.pending);
        expect(banner.soleStep?.id, SetupStepId.appConnected);
        expect(banner.soleStep?.variant, SetupStepVariant.controllerLinkMissing);
      });

      test('is null while several required steps are outstanding', () {
        final banner = deriveBanner([
          link(id: 'c', status: LinkStatus.attention, steps: [true, false]),
          appLink(const [SetupStep(id: SetupStepId.appConnectionMethod, done: true), controllerLinkMissing]),
        ]);
        expect(banner.stepsLeft, 2);
        expect(banner.soleStep, isNull);
      });

      test('an outstanding optional step does not stop the one required step being sole', () {
        final banner = deriveBanner([
          link(id: 'c', status: LinkStatus.ready),
          appLink(const [
            SetupStep(id: SetupStepId.appConnectionMethod, done: true),
            controllerLinkMissing,
            SetupStep(id: SetupStepId.appLocalControl, done: false, optional: true),
          ]),
        ]);
        expect(banner.soleStep?.id, SetupStepId.appConnected);
      });

      test('is null when nothing is outstanding', () {
        final banner = deriveBanner([link(id: 'c', status: LinkStatus.ready)]);
        expect(banner.soleStep, isNull);
      });

      test('a break still outranks it, but the step is still reported', () {
        final banner = deriveBanner([
          link(id: 'c', status: LinkStatus.problem, steps: [true]),
          appLink(const [controllerLinkMissing]),
        ]);
        expect(banner.kind, ChainBannerKind.broken);
        expect(banner.soleStep?.id, SetupStepId.appConnected);
      });
    });
  });

  group('SetupStep', () {
    test('defaults to the standard wording', () {
      expect(const SetupStep(id: SetupStepId.appConnected, done: false).variant, SetupStepVariant.standard);
    });

    test('copyWith keeps the variant and the secondary hint argument', () {
      const step = SetupStep(
        id: SetupStepId.trainerAppBridged,
        done: false,
        hintArg: 'KICKR CORE - BikeControl',
        secondaryHintArg: 'KICKR CORE 1234',
        variant: SetupStepVariant.controllerLinkMissing,
      );
      final copy = step.copyWith(done: true);
      expect(copy.done, isTrue);
      expect(copy.hintArg, 'KICKR CORE - BikeControl');
      expect(copy.secondaryHintArg, 'KICKR CORE 1234');
      expect(copy.variant, SetupStepVariant.controllerLinkMissing);
    });
  });

  group('app link "Show me how"', () {
    ChainLink appLink(List<SetupStepId> pending) => ChainLink(
      key: ChainLinkKey.app,
      id: 'app',
      status: LinkStatus.attention,
      title: 'Rouvy',
      steps: [
        for (final id in SetupStepId.values)
          if (id == SetupStepId.appSelected || id == SetupStepId.appConnectionMethod || id == SetupStepId.appConnected)
            SetupStep(id: id, done: !pending.contains(id)),
      ],
    );

    test('opens Trainer Connections while a method still has to be switched on', () {
      final l = appLink([SetupStepId.appConnectionMethod, SetupStepId.appConnected]);

      expect(l.activeStep?.id, SetupStepId.appConnectionMethod);
      expect(appLinkOpensConnectionSettings(l), isTrue);
    });

    test('falls back to the app guide once a method is on', () {
      final l = appLink([SetupStepId.appConnected]);

      expect(l.activeStep?.id, SetupStepId.appConnected);
      expect(appLinkOpensConnectionSettings(l), isFalse);
    });

    test('falls back to the app guide when no app is picked yet', () {
      final l = appLink([SetupStepId.appSelected, SetupStepId.appConnectionMethod, SetupStepId.appConnected]);

      expect(appLinkOpensConnectionSettings(l), isFalse);
    });

    test('falls back to the app guide when everything is done', () {
      expect(appLinkOpensConnectionSettings(appLink(const [])), isFalse);
    });
  });

  group('appStatusFollowsActiveStep', () {
    ChainLink link(List<SetupStep> steps) =>
        ChainLink(key: ChainLinkKey.app, id: 'app', status: LinkStatus.attention, title: 'MyWhoosh', steps: steps);

    test('names the outstanding step while one is in the way', () {
      // "Waiting for MyWhoosh" while Local Network is denied points the rider
      // at the trainer app to hunt for a problem that is on this device.
      final l = link(const [
        SetupStep(id: SetupStepId.appSelected, done: true),
        SetupStep(id: SetupStepId.appConnectionMethod, done: true),
        SetupStep(id: SetupStepId.appLocalNetwork, done: false),
        SetupStep(id: SetupStepId.appConnected, done: false),
      ]);
      expect(l.activeStep!.id, SetupStepId.appLocalNetwork);
      expect(appStatusFollowsActiveStep(l), isTrue);
    });

    test('says it is waiting once everything on this side is done', () {
      final l = link(const [
        SetupStep(id: SetupStepId.appSelected, done: true),
        SetupStep(id: SetupStepId.appConnectionMethod, done: true),
        SetupStep(id: SetupStepId.appLocalNetwork, done: true),
        SetupStep(id: SetupStepId.appConnected, done: false),
      ]);
      expect(appStatusFollowsActiveStep(l), isFalse);
    });

    test('an optional step never rewrites the status line', () {
      // Local control is an offer, not a blocker — it must not make the card
      // claim the rider has work to do.
      final l = link(const [
        SetupStep(id: SetupStepId.appSelected, done: true),
        SetupStep(id: SetupStepId.appConnectionMethod, done: true),
        SetupStep(id: SetupStepId.appConnected, done: true),
        SetupStep(id: SetupStepId.appLocalControl, done: false, optional: true),
      ]);
      expect(appStatusFollowsActiveStep(l), isFalse);
    });
  });
}
