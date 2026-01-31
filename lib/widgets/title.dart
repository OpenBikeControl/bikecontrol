import 'dart:convert';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
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

enum UpdateType {
  playStore,
  shorebird,
  appStore,
  windowsStore,
}

class _AppTitleState extends State<AppTitle> with WidgetsBindingObserver {
  final updater = ShorebirdUpdater();

  Version? _newVersion;
  UpdateType? _updateType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
              setState(() {
                _updateType = UpdateType.shorebird;
              });
            })
            .catchError((e) {
              buildToast(context, title: AppLocalizations.current.failedToUpdate(e.toString()));
            });
      } else if (updateStatus == UpdateStatus.restartRequired) {
        _updateType = UpdateType.shorebird;
      }
      if (_updateType == UpdateType.shorebird) {
        final nextPatch = await updater.readNextPatch();
        setState(() {
          final currentVersion = Version.parse(packageInfoValue!.version);
          _newVersion = Version(
            currentVersion.major,
            currentVersion.minor,
            currentVersion.patch,
            build: nextPatch?.number.toString() ?? '',
          );
        });
      }
    }

    if (kIsWeb) {
      // no-op
    } else if (Platform.isAndroid) {
      try {
        final appUpdateInfo = await InAppUpdate.checkForUpdate();
        if (context.mounted && appUpdateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          setState(() {
            _updateType = UpdateType.playStore;
          });
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
        r'>Version ([0-9]{1,2}\.[0-9]{1,2}.[0-9]{1,2})</h4>',
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
        GradientText(
          'BikeControl',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        if (packageInfoValue != null)
          Text(
            'v${packageInfoValue!.version}${shorebirdPatch != null ? '+${shorebirdPatch!.number}' : ''} - ${core.settings.getShowOnboarding() ? 'Onboarding' : IAPManager.instance.getStatusMessage()}',
            style: TextStyle(fontSize: 12),
          ).mono.muted
        else
          SmallProgressIndicator(),

        if (_newVersion != null && _updateType != null)
          Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.destructive,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LoadingWidget(
              futureCallback: () async {
                if (_updateType == UpdateType.shorebird) {
                  await _shorebirdRestart();
                } else if (_updateType == UpdateType.playStore) {
                  await launchUrlString(
                    'https://play.google.com/store/apps/details?id=org.jonasbark.swiftcontrol',
                    mode: LaunchMode.externalApplication,
                  );
                } else if (_updateType == UpdateType.appStore) {
                  await launchUrlString(
                    'https://apps.apple.com/app/id6753721284',
                    mode: LaunchMode.externalApplication,
                  );
                } else if (_updateType == UpdateType.windowsStore) {
                  await launchUrlString(
                    'ms-windows-store://pdp/?productid=9NP42GS03Z26',
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              renderChild: (isLoading, tap) => GhostButton(
                onPressed: tap,
                trailing: isLoading ? SmallProgressIndicator() : Icon(Icons.update),
                child: Text(AppLocalizations.current.newVersionAvailableWithVersion(_newVersion.toString())),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _shorebirdRestart() async {
    setState(() {
      core.connection.disconnectAll();
      core.connection.stop();
      if (Platform.isIOS) {
        Restart.restartApp(delayBeforeRestart: 1000);
      } else {
        exit(0);
      }
    });
  }

  void _compareVersion(String versionString) {
    final parsed = Version.parse(versionString);
    final current = Version.parse(packageInfoValue!.version);
    if (parsed > current && mounted && !kDebugMode) {
      if (Platform.isAndroid) {
        setState(() {
          _updateType = UpdateType.playStore;
          _newVersion = parsed;
        });
      } else if (Platform.isIOS || Platform.isMacOS) {
        setState(() {
          _updateType = UpdateType.appStore;
          _newVersion = parsed;
        });
      } else if (Platform.isWindows) {
        setState(() {
          _updateType = UpdateType.appStore;
          _newVersion = parsed;
        });
      }
    }
  }
}
