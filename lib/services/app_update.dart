import 'dart:convert';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/update_track.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:bike_control/widgets/title.dart' show packageInfoValue, isFromPlayStore;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Where an available update comes from — each has its own way of being
/// applied (see [applyAppUpdate]).
enum UpdateType { playStore, shorebird, appStore, windowsStore, linuxDownload }

/// The Linux packages' version, published by CI next to the .deb and AppImage
/// on the rolling `linux-latest` release.
const linuxVersionUrl = 'https://github.com/OpenBikeControl/bikecontrol/releases/download/linux-latest/VERSION.txt';

/// Where a Linux rider picks up the new .deb or AppImage.
const linuxDownloadPage = 'https://github.com/OpenBikeControl/bikecontrol/releases/tag/linux-latest';

/// An update the rider can install right now.
class AppUpdate {
  const AppUpdate({required this.type, this.version});

  final UpdateType type;

  /// The version being offered. Null for the Play Store, whose in-app update
  /// API reports availability without a version number.
  final Version? version;

  /// A Shorebird patch is already downloaded — applying it just restarts.
  bool get isPatch => type == UpdateType.shorebird;
}

/// Checks every update channel this build can use: a downloaded Shorebird
/// patch first (it needs no store round-trip), then the platform's store.
///
/// Shared by the title bar and the onboarding wizard so both agree on what
/// "an update is available" means. Returns null when the app is current, in
/// debug builds, or in [screenshotMode].
Future<AppUpdate?> checkForAppUpdate() async {
  if (screenshotMode || kIsWeb) return null;

  final packageInfo = packageInfoValue ??= await PackageInfo.fromPlatform();
  final current = Version.parse(packageInfo.version);

  final updater = ShorebirdUpdater();
  if (updater.isAvailable) {
    try {
      final track = updateTrackFor(isBetaTester: IAPManager.instance.isBetaTester);
      final status = await updater.checkForUpdate(track: track);
      if (status == UpdateStatus.outdated) {
        await updater.update(track: track);
      }
      if (status == UpdateStatus.outdated || status == UpdateStatus.restartRequired) {
        final nextPatch = await updater.readNextPatch();
        return AppUpdate(
          type: UpdateType.shorebird,
          version: Version(current.major, current.minor, current.patch,
              build: nextPatch?.number.toString() ?? ''),
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Shorebird update check');
    }
  }

  try {
    if (Platform.isAndroid) {
      final info = await InAppUpdate.checkForUpdate();
      isFromPlayStore = true;
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        return const AppUpdate(type: UpdateType.playStore);
      }
    } else if (Platform.isIOS) {
      final response = await http.get(Uri.parse('https://itunes.apple.com/lookup?id=6753721284'));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data['resultCount'] > 0) {
        return _storeUpdate(data['results'][0]['version'] as String, current);
      }
    } else if (Platform.isMacOS) {
      final res = await http.get(
        Uri.parse('https://apps.apple.com/us/app/swiftcontrol/id6753721284?platform=mac'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (res.statusCode != 200) return null;
      final match = RegExp(r'>Version ([0-9]{1,2}\.[0-9]{1,2}.[0-9]{1,2})</h4>', dotAll: true).firstMatch(res.body);
      final versionString = match?.group(1);
      if (versionString != null) return _storeUpdate(versionString, current);
    } else if (Platform.isWindows) {
      final res = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/WINDOWS_STORE_VERSION.txt'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (res.statusCode != 200) return null;
      return _storeUpdate(res.body.trim(), current);
    } else if (Platform.isLinux) {
      final res = await http.get(Uri.parse(linuxVersionUrl), headers: {'User-Agent': 'Mozilla/5.0'});
      if (res.statusCode != 200) return null;
      return _storeUpdate(res.body.trim(), current);
    }
  } on Exception catch (e, s) {
    if (Platform.isAndroid) isFromPlayStore = false;
    recordError(e, s, context: 'Store update check');
  }
  return null;
}

AppUpdate? _storeUpdate(String versionString, Version current) {
  if (kDebugMode) return null;
  return storeUpdateFor(versionString, current, platform: defaultTargetPlatform);
}

/// The update [versionString] from [platform]'s store means for [current], or
/// null when it is not newer.
@visibleForTesting
AppUpdate? storeUpdateFor(String versionString, Version current, {required TargetPlatform platform}) {
  final parsed = Version.parse(versionString);
  if (parsed <= current) return null;
  return switch (platform) {
    TargetPlatform.android => AppUpdate(type: UpdateType.playStore, version: parsed),
    TargetPlatform.iOS || TargetPlatform.macOS => AppUpdate(type: UpdateType.appStore, version: parsed),
    TargetPlatform.windows => AppUpdate(type: UpdateType.windowsStore, version: parsed),
    TargetPlatform.linux => AppUpdate(type: UpdateType.linuxDownload, version: parsed),
    TargetPlatform.fuchsia => null,
  };
}

/// Installs [update]: a Shorebird patch is already downloaded, so the app just
/// restarts into it; store updates open the store listing.
Future<void> applyAppUpdate(AppUpdate update) async {
  switch (update.type) {
    case UpdateType.shorebird:
      core.connection.disconnectAll();
      core.connection.stop();
      if (Platform.isIOS) {
        Restart.restartApp(delayBeforeRestart: 1000);
      } else {
        exit(0);
      }
    case UpdateType.playStore:
      await launchUrlString(
        'https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol',
        mode: LaunchMode.externalApplication,
      );
    case UpdateType.appStore:
      await launchUrlString('https://apps.apple.com/app/id6753721284', mode: LaunchMode.externalApplication);
    case UpdateType.windowsStore:
      await launchUrlString(
        IAPManager.instance.isOutsideStoreWindowsBuild
            ? 'https://bikecontrol.app/download/bikecontrol.windows.zip'
            : 'ms-windows-store://pdp/?productid=9NP42GS03Z26',
        mode: LaunchMode.externalApplication,
      );
    case UpdateType.linuxDownload:
      await launchUrlString(linuxDownloadPage, mode: LaunchMode.externalApplication);
  }
}

/// "Update to 6.4.0+3" — the label both the title bar and the wizard use.
String appUpdateLabel(AppUpdate update) => update.version != null
    ? AppLocalizations.current.newVersionAvailableWithVersion(update.version.toString())
    : AppLocalizations.current.newVersionAvailable;
