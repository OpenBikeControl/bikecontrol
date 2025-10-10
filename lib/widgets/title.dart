import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:version/version.dart';

String? _latestVersionUrlValue;
PackageInfo? _packageInfoValue;
bool isFromPlayStore = true;

class AppTitle extends StatefulWidget {
  const AppTitle({super.key});

  @override
  State<AppTitle> createState() => _AppTitleState();
}

class _AppTitleState extends State<AppTitle> {
  Future<String?> _getLatestVersionUrlIfNewer() async {
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
          return apkUrl;
        } else if (Platform.isMacOS) {
          final dmgUrl = assets.firstOrNullWhere(
            (asset) => asset['name'].endsWith('.macos.zip'),
          )['browser_download_url'];
          return dmgUrl;
        } else if (Platform.isWindows) {
          final appImageUrl = assets.firstOrNullWhere(
            (asset) => asset['name'].endsWith('.windows.zip'),
          )['browser_download_url'];
          return appImageUrl;
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_packageInfoValue == null) {
      PackageInfo.fromPlatform().then((value) {
        setState(() {
          _packageInfoValue = value;
        });
        _checkForUpdate();
      });
    } else {
      _checkForUpdate();
    }
  }

  void _checkForUpdate() async {
    if (!kIsWeb && Platform.isAndroid) {
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
        return null;
      } on Exception catch (e) {
        isFromPlayStore = false;
        print('Failed to check for update: $e');
      }
    }
    if (_latestVersionUrlValue == null && !kIsWeb && !Platform.isIOS) {
      final url = await _getLatestVersionUrlIfNewer();
      if (url != null && mounted && !kDebugMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New version available: ${url.split("/").takeLast(2).first.split('%').first}'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SwiftControl', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_packageInfoValue != null)
          Text(
            'v${_packageInfoValue!.version}',
            style: TextStyle(fontFamily: "monospace", fontFamilyFallback: <String>["Courier"], fontSize: 12),
          )
        else
          SmallProgressIndicator(),
      ],
    );
  }
}
