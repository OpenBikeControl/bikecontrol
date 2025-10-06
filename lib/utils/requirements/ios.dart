import 'dart:developer';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/requirements/platform.dart';

class HomeController {
  bool isAdvertising = false;
  bool isBleOn = false;
  List<String> devices = <String>[];

  String get deviceName => "HID Mouse";

  // HID Service UUID (standard)
  String serviceHID = "00001812-0000-1000-8000-00805F9B34FB";
  // HID Information Characteristic UUID
  String characteristicHIDInformation = "00002A4A-0000-1000-8000-00805F9B34FB";
  // HID Report Map Characteristic UUID
  String characteristicReportMap = "00002A4B-0000-1000-8000-00805F9B34FB";
  // HID Control Point Characteristic UUID
  String characteristicControlPoint = "00002A4C-0000-1000-8000-00805F9B34FB";
  // HID Report Characteristic UUID
  String characteristicReport = "00002A4D-0000-1000-8000-00805F9B34FB";
  // HID Protocol Mode Characteristic UUID
  String characteristicProtocolMode = "00002A4E-0000-1000-8000-00805F9B34FB";

  // HID Report Map for Mouse (standard)
  Uint8List hidReportMap = Uint8List.fromList([
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x02, // Usage (Mouse)
    0xA1, 0x01, // Collection (Application)
    0x09, 0x01, //   Usage (Pointer)
    0xA1, 0x00, //   Collection (Physical)
    0x05, 0x09, //     Usage Page (Button)
    0x19, 0x01, //     Usage Minimum (Button 1)
    0x29, 0x03, //     Usage Maximum (Button 3)
    0x15, 0x00, //     Logical Minimum (0)
    0x25, 0x01, //     Logical Maximum (1)
    0x95, 0x03, //     Report Count (3)
    0x75, 0x01, //     Report Size (1)
    0x81, 0x02, //     Input (Data,Var,Abs)
    0x95, 0x01, //     Report Count (1)
    0x75, 0x05, //     Report Size (5)
    0x81, 0x03, //     Input (Const,Var,Abs) - Reserved
    0x05, 0x01, //     Usage Page (Generic Desktop)
    0x09, 0x30, //     Usage (X)
    0x09, 0x31, //     Usage (Y)
    0x09, 0x38, //     Usage (Wheel)
    0x15, 0x81, //     Logical Minimum (-127)
    0x25, 0x7F, //     Logical Maximum (127)
    0x75, 0x08, //     Report Size (8)
    0x95, 0x03, //     Report Count (3)
    0x81, 0x06, //     Input (Data,Var,Rel)
    0xC0, //   End Collection
    0xC0, // End Collection
  ]);

  // HID Information
  Uint8List hidInformation = Uint8List.fromList([0x11, 0x01, 0x00, 0x03]); // bcdHID=0x0111, bCountryCode=0, Flags=0x03

  void onInit() {
    _initialize();
    // setup callbacks
    BlePeripheral.setBleStateChangeCallback((b) {
      isBleOn = b;
      log("BLE State Changed: $b");
    });

    BlePeripheral.setAdvertisingStatusUpdateCallback((bool advertising, String? error) {
      isAdvertising = advertising;
      log("AdvertisingStarted: $advertising, Error: $error");
    });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback((
      String deviceId,
      String characteristicId,
      bool isSubscribed,
      String? name,
    ) {
      log("onCharacteristicSubscriptionChange: $deviceId : $characteristicId $isSubscribed Name: $name");
      String deviceName = "${name ?? deviceId} subscribed to $characteristicId";
      if (isSubscribed) {
        if (!devices.any((element) => element == deviceName)) {
          devices.add(deviceName);
          log("$deviceName adding");
        } else {
          log("$deviceName already exists");
        }
      } else {
        devices.removeWhere((element) => element == deviceName);
      }
    });

    BlePeripheral.setReadRequestCallback((deviceId, characteristicId, offset, value) {
      log("ReadRequest: $deviceId $characteristicId : $offset : $value");
      // Respond with HID info or report map if requested
      if (characteristicId == characteristicReportMap) {
        return ReadRequestResult(value: hidReportMap);
      }
      if (characteristicId == characteristicHIDInformation) {
        return ReadRequestResult(value: hidInformation);
      }
      return ReadRequestResult(value: Uint8List(0));
    });

    BlePeripheral.setWriteRequestCallback((deviceId, characteristicId, offset, value) {
      log("WriteRequest: $deviceId $characteristicId : $offset : $value");
      // Handle control point or protocol mode writes if needed
      return null;
    });
  }

  void _initialize() async {
    try {
      await BlePeripheral.initialize();
    } catch (e) {
      log("InitializationError: $e");
    }
  }

  Future<void> startAdvertising() async {
    log("Starting Advertising (HID Mouse)");
    await addServices();
    await BlePeripheral.startAdvertising(
      services: [serviceHID],
      localName: deviceName,
      // Optionally set manufacturer data if needed
      addManufacturerDataInScanResponse: false,
    );
  }

  Future<void> addServices() async {
    try {
      // HID Service with the required characteristics
      await BlePeripheral.addService(
        BleService(
          uuid: serviceHID,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: characteristicHIDInformation,
              properties: [CharacteristicProperties.read.index],
              value: hidInformation,
              permissions: [AttributePermissions.readable.index],
            ),
            BleCharacteristic(
              uuid: characteristicReportMap,
              properties: [CharacteristicProperties.read.index],
              value: hidReportMap,
              permissions: [AttributePermissions.readable.index],
            ),
            BleCharacteristic(
              uuid: characteristicControlPoint,
              properties: [CharacteristicProperties.write.index],
              //value: Uint8List(1), // Default 0
              permissions: [AttributePermissions.writeable.index],
            ),
            BleCharacteristic(
              uuid: characteristicReport,
              properties: [CharacteristicProperties.read.index, CharacteristicProperties.notify.index],
              //value: Uint8List(4), // Initial empty mouse report
              permissions: [AttributePermissions.readable.index],
            ),
            BleCharacteristic(
              uuid: characteristicProtocolMode,
              properties: [CharacteristicProperties.read.index, CharacteristicProperties.write.index],
              //value: Uint8List.fromList([1]), // Report protocol mode
              permissions: [AttributePermissions.readable.index, AttributePermissions.writeable.index],
            ),
          ],
        ),
      );
      log("HID Mouse services added");
    } catch (e) {
      log("Error: $e");
    }
  }

  void getAllServices() async {
    List<String> services = await BlePeripheral.getServices();
    log(services.toString());
  }

  void removeServices() async {
    await BlePeripheral.clearServices();
    log("Services removed");
  }

  /// Send a mouse report to all subscribed devices. For example, move mouse right.
  void sendMouseReport({int buttons = 0, int x = 0, int y = 0, int wheel = 0}) async {
    // Mouse report: [buttons, x, y, wheel]
    try {
      Uint8List report = Uint8List.fromList([
        buttons & 0x07, // 3 bits for buttons
        x & 0xFF, // X movement (-127 to +127)
        y & 0xFF, // Y movement (-127 to +127)
        wheel & 0xFF, // Wheel movement (-127 to +127)
      ]);
      await BlePeripheral.updateCharacteristic(characteristicId: characteristicReport, value: report);
      log("Mouse report sent: $report");
    } catch (e) {
      log("SendMouseReportError: $e");
    }
  }
}

class PairRequirement extends PlatformRequirement {
  PairRequirement() : super('Pair to your other iOS device');

  final HomeController homeController = HomeController()..onInit();

  @override
  Future<void> call() async {}

  @override
  Future<void> getStatus() async {
    status = false;
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () {
            homeController.startAdvertising();
          },
          child: Text('Start'),
        ),
        ElevatedButton(
          onPressed: () {
            homeController.sendMouseReport(buttons: 1, x: 10, y: 30); // Move mouse right
          },
          child: Text('Control'),
        ),
      ],
    );
  }
}
