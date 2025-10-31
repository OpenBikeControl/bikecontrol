import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/accessibility_disclosure_dialog.dart';
import 'package:swift_control/widgets/warning.dart';
import 'package:url_launcher/url_launcher.dart';

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
  NotificationRequirement()
    : super('Allow persistent Notification', description: 'This keeps the app alive in background');

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
    AndroidFlutterLocalNotificationsPlugin().stopForegroundService().then((_) {
      exit(0);
    });
  }
}

class MiuiWarningRequirement extends PlatformRequirement {
  static bool? _isMiui;

  MiuiWarningRequirement()
    : super(
        'MIUI Battery Optimization Warning',
        description: 'MIUI devices may kill the accessibility service. Please disable battery optimization.',
      );

  static Future<bool> isMiuiDevice() async {
    if (_isMiui != null) return _isMiui!;
    
    try {
      // Reuse DeviceInfoPlugin instance for efficiency
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      // Check if manufacturer/brand is Xiaomi, Redmi, or Poco (all MIUI-based)
      _isMiui = deviceInfo.manufacturer.toLowerCase() == 'xiaomi' ||
                deviceInfo.brand.toLowerCase() == 'xiaomi' ||
                deviceInfo.brand.toLowerCase() == 'redmi' ||
                deviceInfo.brand.toLowerCase() == 'poco';
      return _isMiui!;
    } catch (e) {
      _isMiui = false;
      return false;
    }
  }

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    // This requirement is purely informational and doesn't require any permission
    // or system setting changes. The user interaction is handled through the
    // build() method which displays the warning and continue button.
  }

  @override
  Future<void> getStatus() async {
    // This requirement is always marked as complete because it's an informational
    // warning that doesn't block the user from proceeding. Unlike requirements
    // that must be fulfilled (like permissions), this just ensures the user is
    // aware of MIUI's battery optimization issues before continuing setup.
    status = true;
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return Warning(
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'MIUI Device Detected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Your device is running MIUI, which is known to aggressively kill background services and accessibility services.',
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 8),
        Text(
          'To ensure SwiftControl works properly:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          '• Disable battery optimization for SwiftControl',
          style: TextStyle(fontSize: 14),
        ),
        Text(
          '• Enable autostart for SwiftControl',
          style: TextStyle(fontSize: 14),
        ),
        Text(
          '• Lock the app in recent apps',
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final url = Uri.parse('https://dontkillmyapp.com/xiaomi');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          icon: Icon(Icons.open_in_new),
          label: Text('View Detailed Instructions'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            onUpdate();
          },
          child: Text('I understand, continue'),
        ),
      ],
    );
  }

  @override
  Widget? buildDescription() {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.orange),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'Please review the battery optimization settings',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      ],
    );
  }
}
