import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/data/mock_universal_ble.dart';
import 'package:universal_ble_example/home/widgets/scan_filter_widget.dart';
import 'package:universal_ble_example/home/widgets/scanned_devices_placeholder_widget.dart';
import 'package:universal_ble_example/home/widgets/scanned_item_widget.dart';
import 'package:universal_ble_example/data/permission_handler.dart';
import 'package:universal_ble_example/peripheral_details/peripheral_detail_page.dart';
import 'package:universal_ble_example/widgets/platform_button.dart';
import 'package:universal_ble_example/widgets/responsive_buttons_grid.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _bleDevices = <BleDevice>[];
  bool _isScanning = false;
  QueueType _queueType = QueueType.global;
  TextEditingController servicesFilterController = TextEditingController();
  TextEditingController namePrefixController = TextEditingController();
  TextEditingController manufacturerDataController = TextEditingController();

  AvailabilityState? bleAvailabilityState;
  ScanFilter? scanFilter;

  @override
  void initState() {
    super.initState();

    /// Set mock instance for testing
    if (const bool.fromEnvironment('MOCK')) {
      UniversalBle.setInstance(MockUniversalBle());
    }

    /// Setup queue and timeout
    UniversalBle.queueType = _queueType;
    UniversalBle.timeout = const Duration(seconds: 10);

    UniversalBle.onAvailabilityChange = (state) {
      setState(() {
        bleAvailabilityState = state;
      });
    };

    UniversalBle.onScanResult = (result) {
      // log(result.toString());
      int index = _bleDevices.indexWhere((e) => e.deviceId == result.deviceId);
      if (index == -1) {
        _bleDevices.add(result);
      } else {
        if (result.name == null && _bleDevices[index].name != null) {
          result.name = _bleDevices[index].name;
        }
        _bleDevices[index] = result;
      }
      setState(() {});
    };

    // UniversalBle.onQueueUpdate = (String id, int remainingItems) {
    //   debugPrint("Queue: $id RemainingItems: $remainingItems");
    // };
  }

  Future<void> startScan() async {
    await UniversalBle.startScan(
      scanFilter: scanFilter,
    );
  }

  Future<void> _getSystemDevices() async {
    // For macOS and iOS, it is recommended to set a filter to get system devices
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS &&
            (scanFilter?.withServices ?? []).isEmpty) {
      showSnackbar(
          "No services filter was set for getting system connected devices. Using default services...");
    }

    List<BleDevice> devices = await UniversalBle.getSystemDevices(
      withServices: scanFilter?.withServices,
    );
    if (devices.isEmpty) {
      showSnackbar("No System Connected Devices Found");
    }
    setState(() {
      _bleDevices.clear();
      _bleDevices.addAll(devices);
    });
  }

  void _showScanFilterBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return ScanFilterWidget(
          servicesFilterController: servicesFilterController,
          namePrefixController: namePrefixController,
          manufacturerDataController: manufacturerDataController,
          onScanFilter: (ScanFilter? filter) {
            setState(() {
              scanFilter = filter;
            });
          },
        );
      },
    );
  }

  void showSnackbar(message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal BLE'),
        elevation: 4,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                  )),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ResponsiveButtonsGrid(
              children: [
                PlatformButton(
                  text: 'Start Scan',
                  onPressed: () async {
                    setState(() {
                      _bleDevices.clear();
                      _isScanning = true;
                    });
                    try {
                      await startScan();
                    } catch (e) {
                      setState(() {
                        _isScanning = false;
                      });
                      showSnackbar(e);
                    }
                  },
                ),
                PlatformButton(
                  text: 'Stop Scan',
                  onPressed: () async {
                    await UniversalBle.stopScan();
                    setState(() {
                      _isScanning = false;
                    });
                  },
                ),
                if (BleCapabilities.supportsBluetoothEnableApi)
                  bleAvailabilityState != AvailabilityState.poweredOn
                      ? PlatformButton(
                          text: 'Enable Bluetooth',
                          onPressed: () async {
                            bool isEnabled =
                                await UniversalBle.enableBluetooth();
                            showSnackbar("BluetoothEnabled: $isEnabled");
                          },
                        )
                      : PlatformButton(
                          text: 'Disable Bluetooth',
                          onPressed: () async {
                            bool isDisabled =
                                await UniversalBle.disableBluetooth();
                            showSnackbar("BluetoothDisabled: $isDisabled");
                          },
                        ),
                if (BleCapabilities.requiresRuntimePermission)
                  PlatformButton(
                    text: 'Check Permissions',
                    onPressed: () async {
                      bool hasPermissions =
                          await PermissionHandler.arePermissionsGranted();
                      if (hasPermissions) {
                        showSnackbar("Permissions granted");
                      }
                    },
                  ),
                if (BleCapabilities.supportsConnectedDevicesApi)
                  PlatformButton(
                    text: 'System Devices',
                    onPressed: _getSystemDevices,
                  ),
                PlatformButton(
                  text: 'Queue: ${_queueType.name}',
                  onPressed: () {
                    setState(() {
                      _queueType = switch (_queueType) {
                        QueueType.global => QueueType.perDevice,
                        QueueType.perDevice => QueueType.none,
                        QueueType.none => QueueType.global,
                      };
                      UniversalBle.queueType = _queueType;
                    });
                  },
                ),
                PlatformButton(
                  text: 'Scan Filters',
                  onPressed: _showScanFilterBottomSheet,
                ),
                if (_bleDevices.isNotEmpty)
                  PlatformButton(
                    text: 'Clear List',
                    onPressed: () {
                      setState(() {
                        _bleDevices.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Ble Availability : ${bleAvailabilityState?.name}',
                ),
              ),
            ],
          ),
          const Divider(color: Colors.blue),
          Expanded(
            child: _isScanning && _bleDevices.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : !_isScanning && _bleDevices.isEmpty
                    ? const ScannedDevicesPlaceholderWidget()
                    : ListView.separated(
                        itemCount: _bleDevices.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          BleDevice device =
                              _bleDevices[_bleDevices.length - index - 1];
                          return ScannedItemWidget(
                            bleDevice: device,
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PeripheralDetailPage(
                                      device.deviceId,
                                      device.name ?? "Unknown Peripheral",
                                    ),
                                  ));
                              UniversalBle.stopScan();
                              setState(() {
                                _isScanning = false;
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
