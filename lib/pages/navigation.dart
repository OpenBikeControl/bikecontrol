import 'dart:async';
import 'dart:io';

import 'package:bike_control/main.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  @override
  void initState() {
    super.initState();

    core.logic.startEnabledConnectionMethod();

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
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
  }

  Future<void> _checkAndShowChangelog() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastSeenVersion = core.settings.getLastSeenVersion();

      if (Platform.isWindows && lastSeenVersion != null && Version.parse(lastSeenVersion) <= Version(5, 0, 0)) {
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
    return Scaffold(
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
    );
  }
}
