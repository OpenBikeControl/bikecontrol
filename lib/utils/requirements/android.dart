import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/accessibility_disclosure_dialog.dart';

class AccessibilityRequirement extends PlatformRequirement {
  AccessibilityRequirement()
    : super(
        'Allow Accessibility Service',
        description: 'SwiftControl needs accessibility permission to control your training apps.',
      );

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    _showDisclosureDialog(context, onUpdate);
  }

  @override
  Future<void> getStatus() async {
    status = await accessibilityHandler.hasPermission();
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
            accessibilityHandler.openPermissions().then((_) {
              onUpdate();
            });
          },
          onDeny: () {
            Navigator.of(context).pop();
            // User denied, no action taken
          },
        );
      },
    );
  }
}

class BluetoothScanRequirement extends PlatformRequirement {
  BluetoothScanRequirement() : super('Allow Bluetooth Scan');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.bluetoothScan.request();
  }

  @override
  Future<void> getStatus() async {
    final state = await Permission.bluetoothScan.status;
    status = state.isGranted || state.isLimited;
  }
}

class LocationRequirement extends PlatformRequirement {
  LocationRequirement() : super('Allow Location so Bluetooth scan works');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    await Permission.locationWhenInUse.request();
  }

  @override
  Future<void> getStatus() async {
    final state = await Permission.locationWhenInUse.status;
    status = state.isGranted || state.isLimited;
  }
}

class BluetoothConnectRequirement extends PlatformRequirement {
  BluetoothConnectRequirement() : super('Allow Bluetooth Connections');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
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
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
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
        notificationTapBackground(n);
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
      'Allows SwiftControl to keep running in background',
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
    AndroidFlutterLocalNotificationsPlugin().stopForegroundService().then((_) {
      exit(0);
    });
  }
}
