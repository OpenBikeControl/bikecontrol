import 'dart:async';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/firmware_support.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/single_line_exception.dart';
import 'package:bike_control/widgets/zwift_ride_firmware_notice.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher_string.dart';

abstract class ZwiftDevice extends BluetoothDevice {
  ZwiftDevice(super.scanResult, {required super.availableButtons, super.isBeta});

  BleCharacteristic? syncRxCharacteristic;

  List<ControllerButton>? _lastButtonsClicked;

  BleService? customService;

  String? get latestFirmwareVersion;
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK;
  bool get canVibrate => false;

  @override
  Future<void> handleServices(List<BleService> services) async {
    customService =
        services.firstOrNullWhere(
          (service) => service.uuid == ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(),
        ) ??
        services.firstOrNullWhere(
          (service) => service.uuid == ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
        );

    if (customService == null) {
      // A controller running firmware NEWER than the last version we support
      // hides its custom service until the vendor app unlocks it. Telling that
      // rider to update is plainly wrong (their firmware is already the
      // latest), so route them to us instead.
      final beyondSupported = hasFirmwareBeyondSupported;
      actionStreamInternal.add(
        beyondSupported
            ? AlertNotification(
                LogLevel.LOGLEVEL_WARNING,
                AppLocalizations.current.zwiftRideFirmwareNoticeBody(firmwareVersion ?? ''),
                buttonTitle: AppLocalizations.current.onboardingHelpSupport,
                onTap: _openFirmwareSupport,
              )
            : AlertNotification(
                LogLevel.LOGLEVEL_ERROR,
                AppLocalizations.current.firmwareUpdateRequired(name),
                buttonTitle: AppLocalizations.current.zwiftCompanionApp,
                onTap: () => launchUrlString(ZwiftConstants.ZWIFT_COMPANION_URL, mode: LaunchMode.externalApplication),
              ),
      );
      final cause = beyondSupported
          ? 'Firmware $firmwareVersion is newer than the last supported version $latestFirmwareVersion.'
          : 'You may need to update the firmware in Zwift Companion app.';
      throw Exception(
        'Custom service ${[ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID, ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID]} not found for device $this ${device.name ?? device.rawName}.\n$cause\nWe found: ${services.joinToString(transform: (s) => s.uuid)}',
      );
    }

    final asyncCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID.toLowerCase(),
    );
    final syncTxCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID.toLowerCase(),
    );
    syncRxCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toLowerCase(),
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, customService!.uuid, asyncCharacteristic.uuid);
    await UniversalBle.subscribeIndications(device.deviceId, customService!.uuid, syncTxCharacteristic.uuid);

    await setupHandshake();

    if (hasNewerFirmwareVersion) {
      actionStreamInternal.add(
        AlertNotification(
          LogLevel.LOGLEVEL_WARNING,
          AppLocalizations.current.firmwareUpdateAvailable(
            name,
            latestFirmwareVersion!,
            firmwareVersion!,
          ),
          buttonTitle: AppLocalizations.current.zwiftCompanionApp,
          onTap: () => launchUrlString(ZwiftConstants.ZWIFT_COMPANION_URL, mode: LaunchMode.externalApplication),
        ),
      );
    }
  }

  /// True when [latestFirmwareVersion] is strictly newer than the firmware we
  /// read off the device. Uses the same lenient parser as
  /// [hasFirmwareBeyondSupported], so a four-component version like `1.2.0.24`
  /// is compared on its leading `major.minor.patch` instead of being discarded.
  /// Fail safe: missing or unparseable input returns false — we never prompt an
  /// update we cannot justify.
  bool get hasNewerFirmwareVersion {
    final installed = parseLenientFirmwareVersion(firmwareVersion);
    final latest = parseLenientFirmwareVersion(latestFirmwareVersion);
    if (installed == null || latest == null) return false;
    return installed < latest;
  }

  /// Opens the in-app support chat for a controller whose firmware is past the
  /// last version we support. Runs from the alert's button, i.e. outside any
  /// widget, so it borrows the root navigator context and stays silent when
  /// there is none (headless/tests).
  void _openFirmwareSupport() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    openZwiftRideFirmwareSupport(context, this);
  }

  /// True when the connected firmware is newer than [latestFirmwareVersion],
  /// the last version we support. For a Zwift Ride that means >1.2.0 — the
  /// server-locked firmware that stops it working with third-party apps.
  /// Fail safe: unparseable or missing versions return false.
  bool get hasFirmwareBeyondSupported => isFirmwareBeyondSupported(firmwareVersion, latestFirmwareVersion);

  Future<void> setupHandshake() async {
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      ZwiftConstants.RIDE_ON,
      withoutResponse: true,
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (bytes.isEmpty) {
      return;
    }

    try {
      if (bytes.startsWith(startCommand)) {
        processDevicePublicKeyResponse(bytes);
      } else {
        processData(bytes);
      }
    } catch (e, stackTrace) {
      print("Error processing data: $e");
      print("Stack Trace: $stackTrace");
      if (e is SingleLineException) {
        actionStreamInternal.add(LogNotification(e.message));
      } else {
        actionStreamInternal.add(LogNotification("$e\n$stackTrace"));
      }
    }
  }

  void processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(
      ZwiftConstants.RIDE_ON.length + ZwiftConstants.RESPONSE_START_CLICK.length,
    );
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  Future<void> processData(Uint8List bytes) async {
    int type = bytes[0];
    Uint8List message = bytes.sublist(1);

    switch (type) {
      case ZwiftConstants.EMPTY_MESSAGE_TYPE:
        //print("Empty Message"); // expected when nothing happening
        break;
      case ZwiftConstants.BATTERY_LEVEL_TYPE:
        if (batteryLevel != message[1]) {
          batteryLevel = message[1];
          core.connection.signalChange(this);
        }
        break;
      case ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case ZwiftConstants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case ZwiftConstants.RIDE_NOTIFICATION_MESSAGE_TYPE:
        try {
          final buttonsClicked = processClickNotification(message);
          handleButtonsClicked(buttonsClicked);
        } catch (e) {
          actionStreamInternal.add(LogNotification(e.toString()));
        }
        break;
    }
  }

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    // the same messages are sent multiple times, so ignore
    if (_lastButtonsClicked == null || _lastButtonsClicked?.contentEquals(buttonsClicked ?? []) == false) {
      super.handleButtonsClicked(buttonsClicked, longPress: longPress);
    }
    _lastButtonsClicked = buttonsClicked;
  }

  List<ControllerButton> processClickNotification(Uint8List message);

  @override
  Future<void> performDown(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.longPress,
  }) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        core.settings.getVibrationEnabled()) {
      await _vibrate();
    }
    return super.performDown(buttonsClicked, trigger: trigger);
  }

  @override
  Future<void> performClick(
    List<ControllerButton> buttonsClicked, {
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        core.settings.getVibrationEnabled() &&
        canVibrate) {
      await _vibrate();
    }
    return super.performClick(buttonsClicked, trigger: trigger);
  }

  Future<void> _vibrate() async {
    final vibrateCommand = Uint8List.fromList([...ZwiftConstants.VIBRATE_PATTERN, 0x20]);
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      vibrateCommand,
      withoutResponse: true,
    );
  }

  @override
  Widget? buildPreferences(BuildContext context) {
    if (!canVibrate) return null;
    return Checkbox(
      trailing: Expanded(child: Text(context.i18n.enableVibrationFeedback)),
      state: core.settings.getVibrationEnabled() ? CheckboxState.checked : CheckboxState.unchecked,
      onChanged: (value) async {
        await core.settings.setVibrationEnabled(value == CheckboxState.checked);
      },
    );
  }
}
