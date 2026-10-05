import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:prop/prop.dart' show LogLevel;

import '../../gen/l10n.dart';
import '../../utils/units.dart';
import '../../widgets/ui/toast.dart';
import '../health/health_workout_channel.dart';
import '../workout/past_workout.dart';
import 'ride_format.dart';
import 'ride_service.dart';

/// Turns [RideService]'s outcomes into toasts and, for a ride that ended in
/// the background, a notification with its numbers.
class RideToastFeedback implements RideFeedback {
  RideToastFeedback({required this.notifications, required this.openHealthSettings});

  final FlutterLocalNotificationsPlugin notifications;
  final Future<void> Function() openHealthSettings;

  static const _notificationId = 1440;
  static const _channelId = 'Rides';

  @override
  void onTooShort() => buildToast(title: AppLocalizations.current.ridesTooShort);

  @override
  void onHealthSaved(HealthStore store) =>
      buildToast(title: AppLocalizations.current.ridesHealthSaved(healthStoreName(store)));

  @override
  void onHealthFailed(HealthStore store, {required bool denied}) {
    final l10n = AppLocalizations.current;
    final name = healthStoreName(store);
    buildToast(
      level: LogLevel.LOGLEVEL_WARNING,
      title: denied ? l10n.ridesHealthDenied(name) : l10n.ridesHealthFailed(name),
      closeTitle: l10n.ridesHealthOpenSettings,
      onClose: () => openHealthSettings(),
    );
  }

  @override
  Future<void> onRideFinishedInBackground(PastWorkout ride) async {
    final summary = ride.summary;
    if (summary == null || kIsWeb) return;
    // Android 13+ asks for notifications; without the grant the ride is
    // still on the summary card, so there is nothing to nag about.
    if (Platform.isAndroid) {
      final android = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.areNotificationsEnabled() == false) return;
    }
    final content = rideNotificationContent(
      summary,
      AppLocalizations.current,
      units: platformUnitSystem,
      locale: Intl.getCurrentLocale(),
    );
    await notifications.show(
      id: _notificationId,
      title: content.title,
      body: content.body,
      payload: rideNotificationPayload(ride),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_channelId, AppLocalizations.current.ridesTab),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
        macOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }
}
