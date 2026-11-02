import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/services/app_update.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app version once read; listen to rebuild when it arrives.
final ValueNotifier<PackageInfo?> packageInfoListenable = ValueNotifier(null);
PackageInfo? get packageInfoValue => packageInfoListenable.value;
set packageInfoValue(PackageInfo? value) => packageInfoListenable.value = value;

bool? isFromPlayStore;

/// The installed Shorebird patch once read (null without one); listen to
/// rebuild when it arrives.
final ValueNotifier<Patch?> shorebirdPatchListenable = ValueNotifier(null);
Patch? get shorebirdPatch => shorebirdPatchListenable.value;
set shorebirdPatch(Patch? value) => shorebirdPatchListenable.value = value;

/// The shell's "New version available" action. Draws nothing until an update
/// is found.
///
/// Always mounted in the top bar, so it is also what reads the app version
/// and the Shorebird patch into [packageInfoValue] and [shorebirdPatch] for
/// the support bundle and the version line (Settings, Help Center).
class AppUpdateButton extends StatefulWidget {
  /// The phone's top bar: a short filled button naming the step ("Restart"
  /// for a downloaded patch, "Update" for the store); the version is then the
  /// spoken label.
  final bool compact;

  /// Skips the check and shows this update — for tests.
  @visibleForTesting
  final AppUpdate? initialUpdate;

  const AppUpdateButton({super.key, this.compact = false, this.initialUpdate});

  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton> with WidgetsBindingObserver {
  final updater = ShorebirdUpdater();

  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _update = widget.initialUpdate;

    if (updater.isAvailable) {
      updater
          .readCurrentPatch()
          .then((patch) {
            core.connection.signalNotification(LogNotification('Current Shorebird patch: $patch'));
            // The version line listens; this widget needs no rebuild.
            shorebirdPatch = patch;
          })
          .catchError((e, s) {
            recordError(e, s, context: 'Shorebird');
          });
    }

    if (packageInfoValue == null) {
      PackageInfo.fromPlatform().then((value) {
        packageInfoValue = value;
        if (mounted) _checkForUpdate();
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
    final update = await checkForAppUpdate();
    if (!mounted || update == null) return;
    setState(() => _update = update);
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    final label = appUpdateLabel(update);
    return LoadingWidget(
      futureCallback: () => applyAppUpdate(update),
      renderChild: (isLoading, tap) {
        if (!widget.compact) {
          return Button.outline(
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.refreshCw),
            child: Text(label).xSmall,
          );
        }
        // A bare icon reads as "refresh", not as "an update is waiting":
        // name the step the rider has to take.
        return Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: PrimaryButton(
            size: ButtonSize.small,
            onPressed: tap,
            leading: isLoading
                ? const SmallProgressIndicator()
                : Icon(update.isPatch ? LucideIcons.rotateCcw : LucideIcons.circleArrowUp, size: 16),
            child: Text(update.isPatch ? context.i18n.onboardingUpdateRestart : context.i18n.onboardingUpdateOpenStore),
          ),
        );
      },
    );
  }

}
