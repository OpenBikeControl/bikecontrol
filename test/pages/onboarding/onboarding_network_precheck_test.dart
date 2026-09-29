// With a network connection method, the connection step runs the network
// self-test's checks in the background. A failing check holds the step with
// what failed and its fix, plus "Check again" and "Continue anyway"; warnings
// don't hold it.
import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_network_precheck.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:bike_control/services/network_self_test/network_method_target.dart';
import 'package:bike_control/widgets/network_check_row.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

NetworkProbeContext _ctx() => NetworkProbeContext(
  snapshot: null,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: false,
  trainerAppConnectedNow: () => false,
  trainerAppName: 'MyWhoosh',
  backend: ObpMdnsBackend.platformDefault,
  advertisedHostname: null,
  platform: 'macos',
  resolve: (h) async => const [],
  tcpProbe: (a, p) async {},
  runProcess: (e, a) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 9, 28),
  onWatchProgress: (p) {},
);

ProbeSpec _s(NetworkCheckId id, NetworkVerdict v, {List<NetworkFixId> fixes = const []}) => ProbeSpec(
  id: id,
  timeout: const Duration(seconds: 5),
  run: (c) async => NetworkCheck(id: id, verdict: v, fixes: fixes),
);

OnboardingNetworkPrecheck _precheck(List<ProbeSpec> probes, {String platform = 'macos'}) => OnboardingNetworkPrecheck(
  engineFactory: () async => NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes),
  platform: platform,
  onResult: (_) async {},
);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('verdicts', () {
    test('a failing check holds the step until the rider continues anyway', () async {
      final p = _precheck([
        _s(NetworkCheckId.methodListening, NetworkVerdict.pass),
        _s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail, fixes: [NetworkFixId.openLocalNetworkSettings]),
      ]);
      await p.run();
      expect(p.phase, NetworkPrecheckPhase.done);
      expect(p.failures.map((c) => c.id), [NetworkCheckId.localNetworkPermission]);
      expect(p.blocking, isTrue);

      p.continueAnyway();
      expect(p.blocking, isFalse);
      p.dispose();
    });

    test('warnings and unknowns do not hold the step', () async {
      final p = _precheck([
        _s(NetworkCheckId.vpn, NetworkVerdict.warn),
        _s(NetworkCheckId.multicastLock, NetworkVerdict.unknown),
      ]);
      await p.run();
      expect(p.blocking, isFalse);
      expect(p.failures, isEmpty);
      p.dispose();
    });

    test("Android's own-hostname lookup does not hold the step", () async {
      final p = _precheck([_s(NetworkCheckId.resolveOwnHostname, NetworkVerdict.fail)], platform: 'android');
      await p.run();
      expect(p.blocking, isFalse);
      p.dispose();
    });

    test('checking again clears "continue anyway" and re-runs', () async {
      var runs = 0;
      final p = OnboardingNetworkPrecheck(
        engineFactory: () async {
          runs++;
          return NetworkSelfTestEngine(
            contextBuilder: _ctx,
            probes: [_s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail)],
          );
        },
        platform: 'macos',
        onResult: (_) async {},
      );
      await p.run();
      p.continueAnyway();
      await p.run();
      expect(runs, 2);
      expect(p.blocking, isTrue);
      p.dispose();
    });

    test('the live watch is never part of the background check', () {
      final ids = OnboardingNetworkPrecheck.backgroundProbes('macos').map((s) => s.id);
      expect(ids, isNot(contains(NetworkCheckId.guidedWatch)));
      expect(ids, isNotEmpty);
    });

    test('disposing mid-run cancels the engine and reports nothing', () async {
      final gate = Completer<void>();
      NetworkSelfTestEngine? engine;
      var results = 0;
      final p = OnboardingNetworkPrecheck(
        engineFactory: () async => engine = NetworkSelfTestEngine(
          contextBuilder: _ctx,
          probes: [
            ProbeSpec(
              id: NetworkCheckId.methodListening,
              timeout: const Duration(seconds: 5),
              run: (c) async {
                await gate.future;
                return const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass);
              },
            ),
            _s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail),
          ],
        ),
        platform: 'macos',
        onResult: (_) async => results++,
      );
      final running = p.run();
      await Future<void>.delayed(Duration.zero);
      expect(p.phase, NetworkPrecheckPhase.checking);
      p.dispose();
      gate.complete();
      await running;
      final result = await engine!.run();
      expect(result.completed, isFalse, reason: 'the engine was cancelled');
      expect(results, 0);
    });
  });

  group('card', () {
    Future<AppLocalizations> pump(WidgetTester tester, OnboardingNetworkPrecheck p, {void Function(NetworkFixId)? onFix}) async {
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            child: SingleChildScrollView(
              child: OnboardingNetworkPrecheckCard(precheck: p, appName: 'MyWhoosh', onFix: onFix ?? (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.of(tester.element(find.byType(OnboardingNetworkPrecheckCard)));
    }

    testWidgets('while checking it shows a compact checking line', (tester) async {
      final gate = Completer<void>();
      final p = OnboardingNetworkPrecheck(
        engineFactory: () async => NetworkSelfTestEngine(
          contextBuilder: _ctx,
          probes: [
            ProbeSpec(
              id: NetworkCheckId.methodListening,
              timeout: const Duration(seconds: 5),
              run: (c) async {
                await gate.future;
                return const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass);
              },
            ),
          ],
        ),
        platform: 'macos',
        onResult: (_) async {},
      );
      unawaited(p.run());
      final l = await pump(tester, p);
      await tester.pump();
      expect(find.text(l.onboardingNetworkChecking), findsOneWidget);
      gate.complete();
      await tester.pump();
      p.dispose();
    });

    testWidgets('a failure shows what failed, its fix, check again and continue anyway', (tester) async {
      final p = _precheck([
        _s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail, fixes: [NetworkFixId.openLocalNetworkSettings]),
      ]);
      await tester.runAsync(p.run);
      final fixes = <NetworkFixId>[];
      final l = await pump(tester, p, onFix: fixes.add);
      final element = tester.element(find.byType(OnboardingNetworkPrecheckCard));

      expect(find.text(l.onboardingNetworkCheckFailedTitle), findsOneWidget);
      expect(find.text(networkCheckTitle(element, NetworkCheckId.localNetworkPermission)), findsOneWidget);

      await tester.tap(find.text(networkFixLabel(element, NetworkFixId.openLocalNetworkSettings)));
      expect(fixes, [NetworkFixId.openLocalNetworkSettings]);

      expect(find.text(l.onboardingNetworkRecheck), findsOneWidget);
      await tester.tap(find.text(l.onboardingNetworkContinueAnyway));
      await tester.pump();
      expect(p.blocking, isFalse);
      expect(find.text(l.onboardingNetworkCheckFailedTitle), findsNothing);
      p.dispose();
    });
  });

  test('the finish button waits for a blocking network problem', () {
    expect(onboardingConnectionCanFinish(hasNoConnectionMethod: false, networkBlocking: false), isTrue);
    expect(onboardingConnectionCanFinish(hasNoConnectionMethod: false, networkBlocking: true), isFalse);
    expect(onboardingConnectionCanFinish(hasNoConnectionMethod: true, networkBlocking: false), isFalse);
  });
  group('gate', () {
    NetworkMethodTarget target(NetworkMethodKind kind, {bool started = true, bool connected = false}) =>
        NetworkMethodTarget(
          kind: kind,
          serverLabel: kind.name,
          preferredPort: 1,
          isStarted: ValueNotifier(started),
          isConnected: ValueNotifier(connected),
        );

    test('the trainer app connecting through the method lifts a failed check', () async {
      final gate = OnboardingNetworkPrecheckGate(
        createPrecheck: (_) => _precheck([_s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail)]),
      );
      final t = target(NetworkMethodKind.openBikeControl);
      gate.sync(wanted: true, target: t);
      await gate.pendingRun;
      expect(gate.precheck!.failures, isNotEmpty);
      expect(gate.blocking, isTrue);

      var notified = 0;
      gate.addListener(() => notified++);
      (t.isConnected as ValueNotifier<bool>).value = true;
      expect(gate.trainerAppConnected, isTrue);
      expect(gate.blocking, isFalse);
      expect(notified, greaterThan(0));
      gate.dispose();
    });

    test('switching the method mid-check drops the old run and checks the new method', () async {
      final hold = Completer<void>();
      final created = <NetworkMethodKind>[];
      final gate = OnboardingNetworkPrecheckGate(
        createPrecheck: (kind) {
          created.add(kind);
          return kind == NetworkMethodKind.openBikeControl
              ? _precheck([
                  ProbeSpec(
                    id: NetworkCheckId.localNetworkPermission,
                    timeout: const Duration(seconds: 5),
                    run: (c) async {
                      await hold.future;
                      return const NetworkCheck(id: NetworkCheckId.localNetworkPermission, verdict: NetworkVerdict.fail);
                    },
                  ),
                ])
              : _precheck([_s(NetworkCheckId.methodListening, NetworkVerdict.pass)]);
        },
      );
      gate.sync(wanted: true, target: target(NetworkMethodKind.openBikeControl));
      final first = gate.precheck;
      await Future<void>.delayed(Duration.zero);
      expect(first!.phase, NetworkPrecheckPhase.checking);

      gate.sync(wanted: true, target: target(NetworkMethodKind.zwiftMdns));
      expect(gate.precheck, isNot(same(first)));
      await gate.pendingRun;
      hold.complete();
      await Future<void>.delayed(Duration.zero);

      expect(created, [NetworkMethodKind.openBikeControl, NetworkMethodKind.zwiftMdns]);
      expect(gate.precheck!.failures, isEmpty);
      expect(gate.blocking, isFalse);
      gate.dispose();
    });

    test('switching the method off and on starts a fresh check', () async {
      var runs = 0;
      final gate = OnboardingNetworkPrecheckGate(
        createPrecheck: (_) {
          runs++;
          return _precheck([_s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail)]);
        },
      );
      final t = target(NetworkMethodKind.rouvyMdns);
      gate.sync(wanted: true, target: t);
      await gate.pendingRun;
      gate.precheck!.continueAnyway();
      gate.sync(wanted: false, target: null);
      expect(gate.precheck, isNull);
      expect(gate.blocking, isFalse);
      gate.sync(wanted: true, target: t);
      await gate.pendingRun;
      expect(runs, 2);
      expect(gate.blocking, isTrue);
      gate.dispose();
    });

    test('waits for the method to start before checking', () async {
      var runs = 0;
      final gate = OnboardingNetworkPrecheckGate(
        createPrecheck: (_) {
          runs++;
          return _precheck([_s(NetworkCheckId.methodListening, NetworkVerdict.pass)]);
        },
      );
      final t = target(NetworkMethodKind.openBikeControl, started: false);
      gate.sync(wanted: true, target: t);
      expect(gate.precheck, isNull);
      (t.isStarted as ValueNotifier<bool>).value = true;
      await gate.pendingRun;
      expect(runs, 1);
      gate.dispose();
    });
  });

  group('failure card', () {
    Future<AppLocalizations> pumpCard(
      WidgetTester tester,
      OnboardingNetworkPrecheck p, {
      Brightness brightness = Brightness.light,
      bool connected = false,
    }) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          theme: BkTheme.build(brightness),
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            child: SingleChildScrollView(
              child: OnboardingNetworkPrecheckCard(
                precheck: p,
                appName: 'MyWhoosh',
                onFix: (_) {},
                trainerAppConnected: connected,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.of(tester.element(find.byType(OnboardingNetworkPrecheckCard)));
    }

    OnboardingNetworkPrecheck failing() => _precheck([
      _s(NetworkCheckId.localNetworkPermission, NetworkVerdict.fail, fixes: [NetworkFixId.openLocalNetworkSettings]),
    ]);

    testWidgets('is announced to screen readers when it appears', (tester) async {
      final p = _precheck([
        ProbeSpec(
          id: NetworkCheckId.localNetworkPermission,
          timeout: const Duration(seconds: 5),
          run: (c) async => const NetworkCheck(id: NetworkCheckId.localNetworkPermission, verdict: NetworkVerdict.fail),
        ),
      ]);
      final l = await pumpCard(tester, p);
      tester.takeAnnouncements();
      await tester.runAsync(p.run);
      await tester.pump();
      final announcements = tester.takeAnnouncements();
      expect(announcements, hasLength(1));
      expect(announcements.single.message, contains(l.onboardingNetworkCheckFailedTitle));
      p.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: its text clears 4.5:1 on its wash', (tester) async {
        final p = failing();
        await tester.runAsync(p.run);
        await pumpCard(tester, p, brightness: brightness);
        expectLegibleText(
          tester,
          find.byKey(const ValueKey('onboarding-network-precheck-failed')),
          pageBackground: BkTheme.build(brightness).colorScheme.background,
        );
        p.dispose();
      });
    }

    testWidgets('its buttons reach 48 dp on a phone', (tester) async {
      final p = failing();
      await tester.runAsync(p.run);
      final l = await pumpCard(tester, p);
      final element = tester.element(find.byType(OnboardingNetworkPrecheckCard));
      for (final label in [
        l.onboardingNetworkRecheck,
        l.onboardingNetworkContinueAnyway,
        networkFixLabel(element, NetworkFixId.openLocalNetworkSettings),
      ]) {
        final target = find.ancestor(of: find.text(label), matching: find.byType(BkTouchTarget));
        expect(target, findsOneWidget, reason: label);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(BkTouchTarget.minSize), reason: label);
      }
      p.dispose();
    });

    testWidgets('once the trainer app is connected the failure shows as resolved', (tester) async {
      final p = failing();
      await tester.runAsync(p.run);
      final l = await pumpCard(tester, p, connected: true);
      expect(find.text(l.onboardingNetworkCheckFailedTitle), findsNothing);
      expect(find.text(l.onboardingNetworkResolvedByConnection('MyWhoosh')), findsOneWidget);
      p.dispose();
    });
  });
}
