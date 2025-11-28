import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/ui/gradient_text.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
import 'package:swift_control/widgets/ui/toast.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:version/version.dart';

PackageInfo? packageInfoValue;
bool? isFromPlayStore;
Patch? shorebirdPatch;

class AppTitle extends StatefulWidget {
  const AppTitle({super.key});

  @override
  State<AppTitle> createState() => _AppTitleState();
}

class _AppTitleState extends State<AppTitle> {
  final updater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();

    if (updater.isAvailable) {
      updater.readCurrentPatch().then((patch) {
        setState(() {
          shorebirdPatch = patch;
        });
      });
    }

    if (packageInfoValue == null) {
      PackageInfo.fromPlatform().then((value) {
        setState(() {
          packageInfoValue = value;
        });
        _checkForUpdate();
      });
    }
  }

  void _checkForUpdate() async {
    if (screenshotMode) {
      return;
    } else if (updater.isAvailable) {
      final updateStatus = await updater.checkForUpdate();
      if (updateStatus == UpdateStatus.outdated) {
        updater
            .update()
            .then((value) {
              _showShorebirdRestartSnackbar();
            })
            .catchError((e) {
              showToast(
                context: context,
                builder: (c, overlay) => buildToast(c, overlay, title: 'Failed to update: $e'),
              );
            });
      } else if (updateStatus == UpdateStatus.restartRequired) {
        _showShorebirdRestartSnackbar();
      }
    }

    if (kIsWeb) {
      // no-op
    } else if (Platform.isAndroid) {
      try {
        final appUpdateInfo = await InAppUpdate.checkForUpdate();
        if (context.mounted && appUpdateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          showToast(
            context: context,
            builder: (c, overlay) => buildToast(
              c,
              overlay,
              title: 'New version available',
              closeTitle: 'Update',
              onClose: () {
                InAppUpdate.performImmediateUpdate();
              },
            ),
          );
        }
        isFromPlayStore = true;
        return null;
      } on Exception catch (e) {
        isFromPlayStore = false;
        print('Failed to check for update: $e');
      }
      setState(() {});
    } else if (Platform.isIOS) {
      final url = Uri.parse('https://itunes.apple.com/lookup?id=6753721284');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          final versionString = data['results'][0]['version'] as String;
          _compareVersion(versionString);
        }
      }
    } else if (Platform.isMacOS) {
      final url = Uri.parse('https://apps.apple.com/us/app/swiftcontrol/id6753721284?platform=mac');
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
      if (res.statusCode != 200) return null;

      final body = res.body;
      final regex = RegExp(
        r'whats-new__latest__version">Version ([0-9]{1,2}\.[0-9]{1,2}.[0-9]{1,2})</p>',
        dotAll: true,
      );
      final match = regex.firstMatch(body);
      if (match == null) return null;
      final versionString = match.group(1);

      if (versionString != null) {
        _compareVersion(versionString);
      }
    } else if (Platform.isWindows) {
      final url = Uri.parse(
        'https://raw.githubusercontent.com/OpenBikeControl/bikecontrol/refs/heads/main/WINDOWS_STORE_VERSION.txt',
      );
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
      if (res.statusCode != 200) return null;

      final body = res.body.trim();
      _compareVersion(body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GradientText('BikeControl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        if (packageInfoValue != null)
          Text(
            'v${packageInfoValue!.version}${shorebirdPatch != null ? '+${shorebirdPatch!.number}' : ''}${kIsWeb || (Platform.isAndroid && isFromPlayStore == false) ? ' (sideloaded)' : ''}',
            style: TextStyle(fontSize: 12),
          ).mono.muted
        else
          SmallProgressIndicator(),
      ],
    );
  }

  void _showShorebirdRestartSnackbar() {
    showToast(
      context: context,
      builder: (c, overlay) => buildToast(
        c,
        overlay,
        title: 'Force-close the app to use the new version',
        closeTitle: 'Restart',
        onClose: () {
          if (Platform.isIOS) {
            connection.reset();
            Restart.restartApp(delayBeforeRestart: 1000);
          } else {
            connection.reset();
            exit(0);
          }
        },
      ),
    );
  }

  void _compareVersion(String versionString) {
    final parsed = Version.parse(versionString);
    final current = Version.parse(packageInfoValue!.version);
    if (parsed > current && mounted && !kDebugMode) {
      if (Platform.isAndroid) {
        _showUpdateSnackbar(parsed, 'https://play.google.com/store/apps/details?id=org.jonasbark.swiftcontrol');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _showUpdateSnackbar(parsed, 'https://apps.apple.com/app/id6753721284');
      } else if (Platform.isWindows) {
        _showUpdateSnackbar(parsed, 'ms-windows-store://pdp/?productid=9NP42GS03Z26');
      }
    }
  }

  void _showUpdateSnackbar(Version newVersion, String url) {
    showToast(
      context: context,
      builder: (c, overlay) => buildToast(
        c,
        overlay,
        title: 'New version available: ${newVersion.toString()}',
        closeTitle: 'Download',
        onClose: () {
          launchUrlString(url);
        },
      ),
    );
  }
}
