import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/activity/activity_log.dart' show activityLogClock;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodType;
import 'package:prop/prop.dart' show LogLevel;

/// A few minutes of a ride in the activity log, for snapshot harnesses: a
/// connection earlier, then shifts, and a press with nothing assigned. Leaves
/// [activityLogClock] pinned at the newest entry, so "ago" labels and the
/// Last minute / Earlier grouping read the same in every capture; reset it to
/// `DateTime.now` in a tearDown.
Future<void> seedRideActivityLog(BaseDevice controller) async {
  final base = DateTime(2026, 9, 29, 10);
  Future<void> at(Duration ago, BaseNotification notification) async {
    activityLogClock = () => base.subtract(ago);
    core.connection.signalNotification(notification);
    await Future<void>.value();
    await Future<void>.value();
  }

  final plus = controller.availableButtons.firstWhere(
    (b) => b.action == InGameAction.shiftUp,
    orElse: () => controller.availableButtons.first,
  );
  final minus = controller.availableButtons.firstWhere(
    (b) => b.action == InGameAction.shiftDown,
    orElse: () => controller.availableButtons.last,
  );
  await at(
    const Duration(minutes: 3),
    AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to MyWhoosh', connectionType: ConnectionMethodType.network),
  );
  await at(const Duration(seconds: 44), ActionNotification(Success('Shifted down to gear 10', button: minus)));
  await at(
    const Duration(seconds: 31),
    ActionNotification(
      Error('Could not perform Z: No action assigned', button: plus, type: ErrorType.noActionAssigned),
    ),
  );
  await at(const Duration(seconds: 6), ActionNotification(Success('Shifted up to gear 11', button: plus)));
  await at(Duration.zero, ActionNotification(Success('Shifted up to gear 12', button: plus)));
  activityLogClock = () => base;
}
