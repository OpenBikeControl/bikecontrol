import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/widgets/ui/gradient_text.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

PackageInfo? packageInfoValue;
bool? isFromPlayStore;
Patch? shorebirdPatch;

class AppTitle extends StatefulWidget {
  const AppTitle({super.key});

  @override
  State<AppTitle> createState() => _AppTitleState();
}

class _AppTitleState extends State<AppTitle> with WidgetsBindingObserver {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GradientText(
          'BikeControl',
          style: context.typography.xLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        if (packageInfoValue != null)
          Text(
            'v${packageInfoValue!.version}${shorebirdPatch != null ? '+${shorebirdPatch!.number}' : ''} - ${IAPManager.instance.getStatusMessage()}',
            style: context.typography.caption.copyWith(
              color: Theme.of(context).colorScheme.mutedForeground.withAlpha(200),
            ),
          ).mono
        else
          SmallProgressIndicator(),

        if (_newVersion != null && _updateType != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LoadingWidget(
              futureCallback: () async {
                await applyAppUpdate(AppUpdate(type: _updateType!, version: _newVersion));
              },
              renderChild: (isLoading, tap) => Button.outline(
                onPressed: tap,
                leading: isLoading ? SmallProgressIndicator() : Icon(Icons.update),
                child: Text(AppLocalizations.current.newVersionAvailableWithVersion(_newVersion.toString())).xSmall,
              ),
            ),
          ),
      ],
    );
  }

  void _onEntitlementsUpdate() {
    setState(() {});
  }
}
