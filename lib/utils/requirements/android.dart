import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/accessibility_disclosure_dialog.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AccessibilityRequirement extends PlatformRequirement {
  AccessibilityRequirement()
    : super(
        AppLocalizations.current.allowAccessibilityService,
        description: AppLocalizations.current.accessibilityDescription,
        icon: Icons.accessibility_new,
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
  BluetoothScanRequirement() : super(AppLocalizations.current.allowBluetoothScan, icon: Icons.bluetooth_searching);

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
  LocationRequirement() : super(AppLocalizations.current.allowLocationForBluetooth, icon: Icons.location_on);

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
  BluetoothConnectRequirement()
    : super(AppLocalizations.current.allowBluetoothConnections, icon: Icons.bluetooth_connected);

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

ReceivePort? _receivePort;
StreamSubscription? _sub;

class NotificationRequirement extends PlatformRequirement {
  NotificationRequirement()
    : super(
        AppLocalizations.current.allowPersistentNotification,
        description: AppLocalizations.current.notificationDescription,
        icon: Icons.notifications_active,
      );
  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {
    if (Platform.isAndroid) {
      final result = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (result == false) {
        buildToast(
          navigatorKey.currentContext!,
          title: 'Enable notifications for BikeControl in Android Settings',
        );
      }
    } else if (Platform.isIOS) {
      final result = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          );
      core.settings.setHasAskedPermissions(true);
      if (result == false) {
        buildToast(
          navigatorKey.currentContext!,
          title: 'Enable notifications for BikeControl in System Preferences → Notifications → Bike Control',
        );
        launchUrlString('x-apple.systempreferences:com.apple.preference.notifications');
      }
    } else if (Platform.isMacOS) {
      final result = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          );
      core.settings.setHasAskedPermissions(true);
      if (result == false) {
        buildToast(
          navigatorKey.currentContext!,
          title: 'Enable notifications for BikeControl in System Preferences → Notifications → Bike Control',
        );
        launchUrlString('x-apple.systempreferences:com.apple.preference.notifications');
      }
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
      status = permissions?.isEnabled == true || core.settings.hasAskedPermissions();
    } else if (Platform.isMacOS) {
      final permissions = await core.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      status = permissions?.isEnabled == true || core.settings.hasAskedPermissions();
    } else {
      status = true;
    }
    return status;
  }

  static Future<void> setup() async {
    print('NOTIFICATION SETUP');
    await core.flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings(
          '@drawable/ic_notification',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'BikeControl',
          appUserModelId: 'OpenBikeControl.BikeControl',
          guid: UUID.short(0x12).toString(),
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
            'disconnect',
            AppLocalizations.current.disconnectDevices,
            cancelNotification: true,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'close',
            AppLocalizations.current.close,
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );

    _receivePort = ReceivePort();
    // If already registered, remove and re-register
    IsolateNameServer.removePortNameMapping('_backgroundChannelKey');
    final ok = IsolateNameServer.registerPortWithName(_receivePort!.sendPort, '_backgroundChannelKey');
    if (!ok) {
      // If this happens, something else re-registered immediately or you’re in a weird state.
      throw StateError('Failed to register port name');
    }
    final backgroundMessagePort = _receivePort!.asBroadcastStream();
    _sub = backgroundMessagePort.listen((message) {
      print('Background isolate received message: $message');
      if (message == 'disconnect' || message == 'close') {
        UniversalBle.onAvailabilityChange = null;
        core.connection.disconnectAll();
      }
      if (message == 'close') {
        core.actionHandler.cleanup();
        core.connection.stop();
        SystemNavigator.pop();
        AndroidFlutterLocalNotificationsPlugin().stopForegroundService();
        AndroidFlutterLocalNotificationsPlugin().cancelAll();
      }

      //exit(0);
    });
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId != null) {
    final sendPort = IsolateNameServer.lookupPortByName('_backgroundChannelKey');
    sendPort?.send(notificationResponse.actionId);
    //exit(0);
  }
}
