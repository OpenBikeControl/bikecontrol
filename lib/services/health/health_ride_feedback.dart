import 'package:prop/prop.dart' show LogLevel;

import '../../gen/l10n.dart';
import '../../widgets/ui/toast.dart';
import 'health_ride_service.dart';
import 'health_workout_channel.dart';

/// Turns [HealthRideService]'s outcomes into toasts. A save reports the
/// ride's headline numbers; a failure or denial offers the one useful next
/// step — the Health app's own permissions screen.
class HealthRideToastFeedback implements HealthRideFeedback {
  const HealthRideToastFeedback({required this.channel});

  final HealthWorkoutChannel channel;

  @override
  void onSaved(HealthRideSaved ride) {
    final l10n = AppLocalizations.current;
    buildToast(
      title: l10n.healthRideSavedTitle,
      subtitle: l10n.healthRideSavedSubtitle(
        _fmtDuration(ride.activeDuration),
        ride.avgPowerW,
        ride.energyKcal.round(),
      ),
    );
  }

  @override
  void onFailed({required bool denied}) {
    final l10n = AppLocalizations.current;
    buildToast(
      level: LogLevel.LOGLEVEL_WARNING,
      title: denied ? l10n.healthRideDeniedTitle : l10n.healthRideFailedTitle,
      closeTitle: l10n.healthRideOpenSettings,
      onClose: () => channel.openHealthSettings(),
    );
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
