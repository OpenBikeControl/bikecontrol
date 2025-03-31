import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

String? _latestVersionUrlValue;
PackageInfo? _packageInfoValue;

class AppTitle extends StatefulWidget {
  const AppTitle({super.key});

  @override
  State<AppTitle> createState() => _AppTitleState();
}

class _AppTitleState extends State<AppTitle> {
  Future<String?> getLatestVersionUrlIfNewer() async {
    final response = await http.get(Uri.parse('https://api.github.com/repos/jonasbark/swiftcontrol/releases/latest'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final latestVersion = data['tag_name'].split('+').first;
      final currentVersion = 'v${_packageInfoValue!.version}';

      if (latestVersion != null && latestVersion != currentVersion) {
        final assets = data['assets'] as List;
        if (Platform.isAndroid) {
          final apkUrl = assets.firstOrNullWhere((asset) => asset['name'].endsWith('.apk'))['browser_download_url'];
          return apkUrl;
        } else if (Platform.isMacOS) {
          final dmgUrl =
              assets.firstOrNullWhere((asset) => asset['name'].endsWith('.macos.zip'))['browser_download_url'];
          return dmgUrl;
        } else if (Platform.isWindows) {
          final appImageUrl =
              assets.firstOrNullWhere((asset) => asset['name'].endsWith('.windows.zip'))['browser_download_url'];
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
        _loadLatestVersionUrl();
      });
    } else {
      _loadLatestVersionUrl();
    }
  }

  void _loadLatestVersionUrl() async {
    if (_latestVersionUrlValue == null && !kIsWeb) {
      final url = await getLatestVersionUrlIfNewer();
      if (url != null && mounted) {
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
    return Row(
      spacing: 8,
      children: [
        Text('SwiftControl'),
        if (_packageInfoValue != null) Text('v${_packageInfoValue!.version}') else SmallProgressIndicator(),
      ],
    );
  }
}
