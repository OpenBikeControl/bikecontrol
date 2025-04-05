import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/platform.dart';

class AccessibilityRequirement extends PlatformRequirement {
  AccessibilityRequirement() : super('Allow Accessibility Service');

  @override
  Future<void> call() async {
    return accessibilityHandler.openPermissions();
  }

  @override
  Future<void> getStatus() async {
    status = await accessibilityHandler.hasPermission();
  }
}

class BluetoothScanRequirement extends PlatformRequirement {
  BluetoothScanRequirement() : super('Allow Bluetooth Scan');

  @override
  Future<void> call() async {
    await Permission.bluetoothScan.request();
  }

  @override
  Future<void> getStatus() async {
    final state = await Permission.bluetoothScan.status;
    status = state.isGranted || state.isLimited;
  }
}

class BluetoothConnectRequirement extends PlatformRequirement {
  BluetoothConnectRequirement() : super('Allow Bluetooth Connections');

  @override
  Future<void> call() async {
    await Permission.bluetoothConnect.request();
  }

  @override
  Future<void> getStatus() async {
    final state = await Permission.bluetoothConnect.status;
    status = state.isGranted || state.isLimited;
  }
}

class NotificationRequirement extends PlatformRequirement {
  NotificationRequirement() : super('Allow adding persistent Notification (keeps app alive)');

  @override
  Future<void> call() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return;
  }

  @override
  Future<void> getStatus() async {
    final bool granted =
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        false;
    status = granted;
  }

  static Future<void> setup() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: initializationSettingsAndroid),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (n) {
        if (n.actionId != null) {
          connection.reset();
          exit(0);
        }
      },
    );

    const String channelGroupId = 'SwiftControl';
    // create the group first
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannelGroup(
          AndroidNotificationChannelGroup(channelGroupId, channelGroupId, description: 'Keep Alive'),
        );

    // create channels associated with the group
    await flutterLocalNotificationsPlugin
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
      'Bluetooth keep alive',
      foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeConnectedDevice},
      notificationDetails: AndroidNotificationDetails(
        channelGroupId,
        'Keep Alive',
        actions: [AndroidNotificationAction('Exit', 'Exit', cancelNotification: true, showsUserInterface: false)],
      ),
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId != null) {
    connection.reset();
    exit(0);
  }
}
