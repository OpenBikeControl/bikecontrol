import 'package:bike_control/utils/window_size.dart';
import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/services/overlay/overlay_reassert_scheduler.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

import '../pages/onboarding/onboarding_page.dart';
import '../pages/onboarding/onboarding_trigger.dart';
import '../utils/settings/settings.dart';
import '../widgets/changelog_dialog.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key, this.initialSection = AppSection.ride});

  /// The section on screen first (Ride). Tests and renders open another.
  final AppSection initialSection;

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _isMobile = false;
  final ShellController _shell = ShellController();
  StreamSubscription<BaseDevice>? _overlayAutoShowSub;
  OverlayReassertScheduler? _reassertScheduler;
  StreamSubscription<BaseDevice>? _reassertConnSub;

  @override
  void initState() {
    super.initState();
    _shell.select(widget.initialSection);
    // Fetched up front so the Activity item can show its new-posts dot before
    // anyone opens News.
    if (BlogNewsController.fetchesAtStart) unawaited(_shell.news.load());

    core.logic.startEnabledConnectionMethod();

    // Keep the Android gear overlay above a trainer app that comes to the
    // foreground after the overlay was shown. The overlay is a system window
    // added while BikeControl is foreground; when Rouvy takes over it ends up
    // buried and stays hidden until re-added (support 73367365). Re-top it on
    // the rising edge of a proxy's "trainer app connected" signal — the moment
    // the trainer app grabs the virtual trainer. Watch every proxy present now
    // and any that connect later; the scheduler gates on the overlay being
    // enabled + showing and debounces flapping reconnects, and reassert() is a
    // no-op off Android, so this is Android-only by construction.
    if (Platform.isAndroid) {
      final scheduler = OverlayReassertScheduler(
        TrainerOverlayService.forCurrentPlatform(),
        isEnabled: core.settings.getOverlayEnabled,
      );
      for (final d in core.connection.proxyDevices) {
        scheduler.watch(d.isConnectedListenable);
      }
      _reassertConnSub = core.connection.connectionStream.listen((d) {
        if (d is ProxyDevice) scheduler.watch(d.isConnectedListenable);
      });
      _reassertScheduler = scheduler;
    }

    if (core.settings.getOverlayEnabled()) {
      // Check whether a smart trainer is already connected (re-mount case).
      var shown = false;
      for (final d in core.connection.proxyDevices) {
        if (_tryAutoShowOverlayFor(d)) {
          shown = true;
          break;
        }
      }
      if (!shown) {
        // Otherwise wait for the next connect event from a smart trainer.
        _overlayAutoShowSub = core.connection.connectionStream.listen((d) {
          if (_tryAutoShowOverlayFor(d)) {
            _overlayAutoShowSub?.cancel();
            _overlayAutoShowSub = null;
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        Theme.of(context).colorScheme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      );
      _checkAndShowChangelog();
    });
  }

  @override
  void dispose() {
    _overlayAutoShowSub?.cancel();
    _reassertConnSub?.cancel();
    _reassertScheduler?.dispose();
    _shell.dispose();
    super.dispose();
  }

  /// Returns true when the overlay was shown for [device]. Called both for
  /// already-connected devices on mount and for new events on the connection
  /// stream. The caller cancels the stream subscription on the first true.
  bool _tryAutoShowOverlayFor(BaseDevice device) {
    if (device is! ProxyDevice) return false;
    if (!device.isSmartTrainer || !device.isConnected) return false;
    final def = device.fitnessBike;
    if (def == null) return false;

    final controller = TrainerOverlayService.forCurrentPlatform();
    if (controller.isShowing.value) return true;

    controller.show(
      def,
      core.settings.getOverlayFields(),
      // ProxyDevice.fitnessBike always returns the current FBD regardless of
      // which emulator is active, so this stays live across mode swaps.
      liveDef: () => device.fitnessBike,
    );
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = isCompactWindow(context);
  }

  Future<void> _checkAndShowChangelog() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastSeenVersion = core.settings.getLastSeenVersion();

      if (!kIsWeb &&
          Platform.isWindows &&
          lastSeenVersion != null &&
          Version.parse(lastSeenVersion) <= Version(5, 0, 0)) {
        IAPManager.instance.setWinBoughtBefore50();
      }

      try {
        final onboardingAction = decideOnboardingTrigger(
          lastSeenVersion: lastSeenVersion,
          onboardingState: core.settings.getOnboardingState(),
        );
        if (onboardingAction == OnboardingTriggerAction.markCompleted) {
          await core.settings.setOnboardingState(Settings.onboardingStateCompleted);
        } else if (onboardingAction == OnboardingTriggerAction.show && !screenshotMode) {
          await core.settings.setOnboardingState(Settings.onboardingStatePending);
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(fullscreenDialog: true, builder: (_) => OnboardingPage()),
            );
          }
        }
      } catch (e, s) {
        recordError(e, s, context: 'onboarding trigger');
      }

      if (mounted) {
        await ChangelogDialog.showIfNeeded(context, currentVersion, lastSeenVersion);
      }

      // Update last seen version
      await core.settings.setLastSeenVersion(currentVersion);
    } catch (e) {
      print('Failed to check changelog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final content = KeyedSubtree(
      key: const ValueKey('shell-content'),
      child: OverviewPage(isMobile: _isMobile, shell: _shell),
    );

    // Not a plain Scaffold: the support screenshot must not show the sheet or
    // toast a rider opens support from, and shadcn paints those inside it.
    return ValueListenableBuilder<AppSection>(
      valueListenable: _shell.section,
      builder: (context, section, _) {
        switch (size) {
          case WindowSize.compact:
            return ScreenshotScaffold(
              headers: [
                ShellTopBar(
                  section: section,
                  compact: true,
                  showPlanAndHelp: section == AppSection.ride,
                  activity: _shell.activity,
                  activityTab: _shell.activityTab,
                ),
              ],
              // The tab bar has its own space below the content, never on top
              // of it.
              footers: [ShellTabBar(controller: _shell)],
              child: content,
            );
          case WindowSize.medium:
            return ScreenshotScaffold(
              headers: [
                ShellTopTabs(controller: _shell),
                // Lined up with the centred content column below it.
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720 + 48),
                    child: ShellTopBar(
                      section: section,
                      compact: false,
                      showPlanAndHelp: section == AppSection.ride,
                      activity: _shell.activity,
                      activityTab: _shell.activityTab,
                    ),
                  ),
                ),
              ],
              child: content,
            );
          case WindowSize.expanded:
            return ScreenshotScaffold(
              headers: const [],
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShellSidebar(controller: _shell),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShellTopBar(
                            section: section,
                            compact: false,
                            activity: _shell.activity,
                            activityTab: _shell.activityTab,
                            shell: _shell,
                          ),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
