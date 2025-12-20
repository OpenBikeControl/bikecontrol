import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class AccessibilityRequirement extends PlatformRequirement {
  AccessibilityRequirement()
    : super(
        AppLocalizations.current.allowAccessibilityService,
        description: AppLocalizations.current.accessibilityDescription,
      );

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await _showDisclosureDialog(context, onUpdate);
    await getStatus();
  }

  @override
  Future<bool> getStatus() async {
    status = await (core.actionHandler as AndroidActions).accessibilityHandler.hasPermission();
    return status;
  }

  Future<void> _showDisclosureDialog(BuildContext context, VoidCallback onUpdate) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AccessibilityDisclosureDialog(
          onAccept: () {
            Navigator.of(context).pop();
            // Open accessibility settings after user consents
            (core.actionHandler as AndroidActions).accessibilityHandler.openPermissions().then((_) async {
              await getStatus();
              onUpdate();
            });
          },
          onDeny: () async {
            await getStatus();
            Navigator.of(context).pop();
            // User denied, no action taken
          },
        );
      },
    );
  }
}

class BluetoothScanRequirement extends PlatformRequirement {
  BluetoothScanRequirement() : super(AppLocalizations.current.allowBluetoothScan);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.bluetoothScan.request();
    await getStatus();
  }

  @override
  Future<bool> getStatus() async {
    final state = await Permission.bluetoothScan.status;
    status = state.isGranted || state.isLimited;
    return status;
  }
}

class LocationRequirement extends PlatformRequirement {
  LocationRequirement() : super(AppLocalizations.current.allowLocationForBluetooth);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.locationWhenInUse.request();
    await getStatus();
  }

  @override
  Future<bool> getStatus() async {
    final state = await Permission.locationWhenInUse.status;
    status = state.isGranted || state.isLimited;
    return status;
  }
}

class BluetoothConnectRequirement extends PlatformRequirement {
  BluetoothConnectRequirement() : super(AppLocalizations.current.allowBluetoothConnections);

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.bluetoothConnect.request();
    await getStatus();
  }

  @override
  Future<bool> getStatus() async {
    final state = await Permission.bluetoothConnect.status;
    status = state.isGranted || state.isLimited;
    return status;
  }
}

class NotificationRequirement extends PlatformRequirement {
  NotificationRequirement()
    : super(
        AppLocalizations.current.allowPersistentNotification,
        description: AppLocalizations.current.notificationDescription,
      );
  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    if (Platform.isAndroid) {
      await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          );
    } else if (Platform.isMacOS) {
      await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          );
    }
    await getStatus();
    return;
  }

  @override
  Future<bool> getStatus() async {
    if (Platform.isAndroid) {
      final bool granted =
          await core.flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
      status = granted;
    } else if (Platform.isIOS) {
      final permissions = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      status = permissions?.isEnabled == true;
    } else if (Platform.isMacOS) {
      final permissions = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      status = permissions?.isEnabled == true;
    } else {
      status = true;
    }
    if (status) {
      await setup();
    }
    return status;
  }

  static Future<void> setup() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await core.flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
        ),
      ),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (n) {
        notificationTapBackground(n);
      },
    );
  }

  static Future<void> addPersistentNotification() async {
    const String channelGroupId = 'BikeControl';
    // create the group first
    await core.flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannelGroup(
          AndroidNotificationChannelGroup(channelGroupId, channelGroupId, description: 'Keep Alive'),
        );

    // create channels associated with the group
    await core.flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(
          const AndroidNotificationChannel(
            channelGroupId,
            channelGroupId,
            description: 'Keep Alive',
            groupId: channelGroupId,
          ),
        );

    await AndroidFlutterLocalNotificationsPlugin().startForegroundService(
      1,
      channelGroupId,
      AppLocalizations.current.allowsRunningInBackground,
      foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeConnectedDevice},
      startType: AndroidServiceStartType.startRedeliverIntent,
      notificationDetails: AndroidNotificationDetails(
        channelGroupId,
        'Keep Alive',
        actions: [
          AndroidNotificationAction(
            AppLocalizations.current.disconnectDevices,
            AppLocalizations.current.disconnectDevices,
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );

    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, '_backgroundChannelKey');
    final backgroundMessagePort = receivePort.asBroadcastStream();
    backgroundMessagePort.listen((_) {
      UniversalBle.onAvailabilityChange = null;
      core.connection.reset();
      //exit(0);
    });
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId != null) {
    final sendPort = IsolateNameServer.lookupPortByName('_backgroundChannelKey');
    sendPort?.send('notificationResponse');
    //exit(0);
  }
}
