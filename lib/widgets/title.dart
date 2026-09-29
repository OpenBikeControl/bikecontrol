import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

PackageInfo? packageInfoValue;
bool? isFromPlayStore;
Patch? shorebirdPatch;

/// The shell's "New version available" action. Draws nothing until an update
/// is found.
///
/// Always mounted in the top bar, so it is also what reads the app version
/// and the Shorebird patch into [packageInfoValue] and [shorebirdPatch] for
/// the support bundle and the Settings version row.
class AppUpdateButton extends StatefulWidget {
  /// Icon only (the phone's top bar); the version is then the spoken label.
  final bool compact;
  const AppUpdateButton({super.key, this.compact = false});

  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton> with WidgetsBindingObserver {
  final updater = ShorebirdUpdater();

  Version? _newVersion;
  UpdateType? _updateType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IAPManager.instance.entitlements.addListener(_onEntitlementsUpdate);

    if (updater.isAvailable) {
      updater
          .readCurrentPatch()
          .then((patch) {
            core.connection.signalNotification(LogNotification('Current Shorebird patch: $patch'));
            setState(() {
              shorebirdPatch = patch;
            });
          })
          .catchError((e, s) {
            recordError(e, s, context: 'Shorebird');
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
    IAPManager.instance.entitlements.removeListener(_onEntitlementsUpdate);
    super.dispose();
  }

  void _checkForUpdate() async {
    final update = await checkForAppUpdate();
    if (!mounted || update == null) return;
    setState(() {
      _updateType = update.type;
      _newVersion = update.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_newVersion == null || _updateType == null) return const SizedBox.shrink();
    final label = AppLocalizations.current.newVersionAvailableWithVersion(_newVersion.toString());
    return LoadingWidget(
      futureCallback: () async {
        await applyAppUpdate(AppUpdate(type: _updateType!, version: _newVersion));
      },
      renderChild: (isLoading, tap) => widget.compact
          ? BkIconButton.outline(
              icon: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.refreshCw, size: 18),
              label: label,
              onPressed: tap,
            )
          : Button.outline(
              onPressed: tap,
              leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.refreshCw),
              child: Text(label).xSmall,
            ),
    );
  }

  void _onEntitlementsUpdate() {
    setState(() {});
  }
}

/// The running version as the Settings row shows it ("7.1.0+3"), or null
/// before [AppUpdateButton] has read it.
String? appVersionLabel() {
  final info = packageInfoValue;
  if (info == null) return null;
  return '${info.version}${shorebirdPatch != null ? '+${shorebirdPatch!.number}' : ''}';
}
