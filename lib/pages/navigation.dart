import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

import '../widgets/changelog_dialog.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _isMobile = false;
  StreamSubscription<BaseDevice>? _overlayAutoShowSub;

  @override
  void initState() {
    super.initState();

    core.logic.startEnabledConnectionMethod();

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
    super.dispose();
  }

  /// Returns true when the overlay was shown for [device]. Called both for
  /// already-connected devices on mount and for new events on the connection
  /// stream. The caller cancels the stream subscription on the first true.
  bool _tryAutoShowOverlayFor(BaseDevice device) {
    if (device is! ProxyDevice) return false;
    if (!device.isSmartTrainer || !device.isConnected) return false;
    final def = device.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return false;

    final controller = TrainerOverlayService.forCurrentPlatform();
    if (controller.isShowing.value) return true;

    controller.show(
      def,
      core.settings.getOverlayFields(),
      // The emulator rebinds a new FitnessBikeDefinition each time a trainer
      // app connects, so capturing `def` here would freeze action handling
      // against a stale instance.
      liveDef: () {
        final live = device.emulator.activeDefinition;
        return live is FitnessBikeDefinition ? live : null;
      },
    );
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
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
    return RepaintBoundary(
      key: overviewScreenshotKey,
      child: Scaffold(
        headers: [
          Stack(
            children: [
              AppBar(
                padding:
                    const EdgeInsets.only(top: 12, bottom: 8, left: 12, right: 12) *
                    (screenshotMode ? 2 : Theme.of(context).scaling),
                title: AppTitle(),
                backgroundColor: Theme.of(context).colorScheme.background,
                trailing: buildMenuButtons(context),
              ),
              if (!_isMobile && !screenshotMode)
                Container(
                  alignment: Alignment.topCenter,
                  child: HelpButton(isMobile: false),
                ),
            ],
          ),
          Divider(),
        ],
        footers: [
          if (_isMobile)
            Container(
              alignment: Alignment.bottomCenter,
              child: HelpButton(isMobile: true),
            ),
        ],
        floatingFooter: true,
        child: OverviewPage(isMobile: _isMobile),
      ),
    );
  }
}
