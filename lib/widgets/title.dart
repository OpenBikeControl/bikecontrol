import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:version/version.dart';

PackageInfo? _packageInfoValue;
bool? isFromPlayStore;

class AppTitle extends StatefulWidget {
  const AppTitle({super.key});

  @override
  State<AppTitle> createState() => _AppTitleState();
}

class _AppTitleState extends State<AppTitle> {
  final updater = ShorebirdUpdater();
  Patch? _shorebirdPatch;

  Future<Pair<Version, String>?> _getLatestVersionUrlIfNewer() async {
    final response = await http.get(Uri.parse('https://api.github.com/repos/jonasbark/swiftcontrol/releases/latest'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tagName = data['tag_name'] as String;
      final prerelase = data['prerelease'] as bool;
      final latestVersion = Version.parse(tagName.split('+').first.replaceAll('v', ''));
      final currentVersion = Version.parse(_packageInfoValue!.version);

      // +1337 releases are considered beta
      if (latestVersion > currentVersion && !prerelase) {
        final assets = data['assets'] as List;
        if (Platform.isAndroid) {
          final apkUrl = assets.firstOrNullWhere((asset) => asset['name'].endsWith('.apk'))['browser_download_url'];
          return Pair(latestVersion, apkUrl);
        } else if (Platform.isMacOS) {
          final dmgUrl = assets.firstOrNullWhere(
            (asset) => asset['name'].endsWith('.macos.zip'),
          )['browser_download_url'];
          return Pair(latestVersion, dmgUrl);
        } else if (Platform.isWindows) {
          final appImageUrl = assets.firstOrNullWhere(
            (asset) => asset['name'].endsWith('.windows.zip'),
          )['browser_download_url'];
          return Pair(latestVersion, appImageUrl);
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    if (updater.isAvailable) {
      updater.readCurrentPatch().then((patch) {
        setState(() {
          _shorebirdPatch = patch;
        });
      });
    }

    if (_packageInfoValue == null) {
      PackageInfo.fromPlatform().then((value) {
        setState(() {
          _packageInfoValue = value;
        });
        _checkForUpdate();
      });
    }
  }

  void _checkForUpdate() async {
    if (updater.isAvailable) {
      final updateStatus = await updater.checkForUpdate();
      if (updateStatus == UpdateStatus.outdated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New version available'),
            duration: Duration(seconds: 1337),
            action: SnackBarAction(
              label: 'Update',
              onPressed: () {
                updater
                    .update()
                    .then((value) {
                      _showShorebirdRestartSnackbar();
                    })
                    .catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update: $e'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    });
              },
            ),
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New version available'),
              duration: Duration(seconds: 1337),
              action: SnackBarAction(
                label: 'Update',
                onPressed: () {
                  InAppUpdate.performImmediateUpdate();
                },
              ),
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
      final updatePair = await _getLatestVersionUrlIfNewer();
      if (updatePair != null && mounted && !kDebugMode) {
        _showUpdateSnackbar(updatePair.first, updatePair.second);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SwiftControl', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_packageInfoValue != null)
          Text(
            'v${_packageInfoValue!.version}${_shorebirdPatch != null ? '+${_shorebirdPatch!.number}' : ''}${kIsWeb || (Platform.isAndroid && isFromPlayStore == false) ? ' (sideloaded)' : ''}',
            style: TextStyle(fontFamily: "monospace", fontFamilyFallback: <String>["Courier"], fontSize: 12),
          )
        else
          SmallProgressIndicator(),
      ],
    );
  }

  void _showShorebirdRestartSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restart the app to use the new version'),
        duration: Duration(seconds: 10),
        action: Platform.isIOS || Platform.isAndroid
            ? SnackBarAction(
                label: 'Restart',
                onPressed: () {
                  connection.reset();
                  Restart.restartApp();
                },
              )
            : null,
      ),
    );
  }

  void _compareVersion(String versionString) {
    final parsed = Version.parse(versionString);
    final current = Version.parse(_packageInfoValue!.version);
    if (parsed > current && mounted && !kDebugMode) {
      if (Platform.isAndroid) {
        _showUpdateSnackbar(parsed, 'https://play.google.com/store/apps/details?id=org.jonasbark.swiftcontrol');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _showUpdateSnackbar(parsed, 'https://apps.apple.com/app/id6753721284');
      }
    }
  }

  void _showUpdateSnackbar(Version newVersion, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New version available: ${newVersion.toString()}'),
        duration: Duration(seconds: 1337),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () {
            launchUrlString(url);
          },
        ),
      ),
    );
  }
}
