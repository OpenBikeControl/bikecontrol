// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/peripheral_details/widgets/result_widget.dart';
import 'package:universal_ble_example/peripheral_details/widgets/services_list_widget.dart';
import 'package:universal_ble_example/widgets/platform_button.dart';
import 'package:universal_ble_example/widgets/responsive_buttons_grid.dart';
import 'package:universal_ble_example/widgets/responsive_view.dart';

class PeripheralDetailPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const PeripheralDetailPage(this.deviceId, this.deviceName, {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  bool isConnected = false;
  GlobalKey<FormState> valueFormKey = GlobalKey<FormState>();
  List<BleService> discoveredServices = [];
  final List<String> _logs = [];
  final binaryCode = TextEditingController();

  ({
    BleService service,
    BleCharacteristic characteristic
  })? selectedCharacteristic;

  @override
  void initState() {
    super.initState();
    UniversalBle.onConnectionChange = _handleConnectionChange;
    UniversalBle.onValueChange = _handleValueChange;
    UniversalBle.onPairingStateChange = _handlePairingStateChange;
  }

  @override
  void dispose() {
    super.dispose();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    // Disconnect when leaving the page
    if (isConnected) UniversalBle.disconnect(widget.deviceId);
  }

  void _addLog(String type, dynamic data) {
    setState(() {
      _logs.add('$type: ${data.toString()}');
    });
  }

  void _handleConnectionChange(
    String deviceId,
    bool isConnected,
    String? error,
  ) {
    print(
      '_handleConnectionChange $deviceId, $isConnected ${error != null ? 'Error: $error' : ''}',
    );
    setState(() {
      if (deviceId == widget.deviceId) {
        this.isConnected = isConnected;
      }
    });
    _addLog('Connection', isConnected ? "Connected" : "Disconnected");
    // Auto Discover Services
    if (this.isConnected) {
      _discoverServices();
    }
  }

  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    String s = String.fromCharCodes(value);
    String data = '$s\nraw :  ${value.toString()}';
    print('_handleValueChange $deviceId, $characteristicId, $s');
    _addLog("Value", data);
  }

  void _handlePairingStateChange(String deviceId, bool isPaired) {
    print('isPaired $deviceId, $isPaired');
    _addLog("PairingStateChange - isPaired", isPaired);
  }

  Future<void> _discoverServices() async {
    const webWarning =
        "Note: Only services added in ScanFilter or WebOptions will be discovered";
    try {
      var services = await UniversalBle.discoverServices(widget.deviceId);
      print('${services.length} services discovered');
      print(services);
      discoveredServices.clear();
      setState(() {
        discoveredServices = services;
      });

      if (kIsWeb) {
        _addLog(
          "DiscoverServices",
          '${services.length} services discovered,\n$webWarning',
        );
      }
    } catch (e) {
      _addLog("DiscoverServicesError", '$e\n${kIsWeb ? webWarning : ""}');
    }
  }

  Future<void> _readValue() async {
    if (selectedCharacteristic == null) return;
    try {
      Uint8List value = await UniversalBle.readValue(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
      );
      String s = String.fromCharCodes(value);
      String data = '$s\nraw :  ${value.toString()}';
      _addLog('Read', data);
    } catch (e) {
      _addLog('ReadError', e);
    }
  }

  Future<void> _writeValue() async {
    if (selectedCharacteristic == null ||
        !valueFormKey.currentState!.validate() ||
        binaryCode.text.isEmpty) {
      return;
    }

    Uint8List value;
    try {
      value = Uint8List.fromList(hex.decode(binaryCode.text));
    } catch (e) {
      _addLog('WriteError', "Error parsing hex $e");
      return;
    }

    try {
      await UniversalBle.writeValue(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        value,
        _hasSelectedCharacteristicProperty(
                [CharacteristicProperty.writeWithoutResponse])
            ? BleOutputProperty.withoutResponse
            : BleOutputProperty.withResponse,
      );
      _addLog('Write', value);
    } catch (e) {
      print(e);
      _addLog('WriteError', e);
    }
  }

  Future<void> _setBleInputProperty(BleInputProperty inputProperty) async {
    if (selectedCharacteristic == null) return;
    try {
      if (inputProperty != BleInputProperty.disabled) {
        List<CharacteristicProperty> properties =
            selectedCharacteristic!.characteristic.properties;
        if (properties.contains(CharacteristicProperty.notify)) {
          inputProperty = BleInputProperty.notification;
        } else if (properties.contains(CharacteristicProperty.indicate)) {
          inputProperty = BleInputProperty.indication;
        } else {
          throw 'No notify or indicate property';
        }
      }
      await UniversalBle.setNotifiable(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        inputProperty,
      );
      _addLog('BleInputProperty', inputProperty);
    } catch (e) {
      _addLog('NotifyError', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.deviceName} - ${widget.deviceId}"),
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.red,
              size: 20,
            ),
          )
        ],
      ),
      body: ResponsiveView(builder: (_, DeviceType deviceType) {
        return Row(
          children: [
            if (deviceType == DeviceType.desktop)
              Expanded(
                flex: 1,
                child: Container(
                  color: Theme.of(context).secondaryHeaderColor,
                  child: discoveredServices.isEmpty
                      ? const Center(
                          child: Text('No Services Discovered'),
                        )
                      : ServicesListWidget(
                          discoveredServices: discoveredServices,
                          scrollable: true,
                          onTap: (BleService service,
                              BleCharacteristic characteristic) {
                            setState(() {
                              selectedCharacteristic = (
                                service: service,
                                characteristic: characteristic
                              );
                            });
                          },
                        ),
                ),
              ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Top buttons
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            PlatformButton(
                              text: 'Connect',
                              enabled: !isConnected,
                              onPressed: () async {
                                try {
                                  await UniversalBle.connect(
                                    widget.deviceId,
                                  );
                                  _addLog("ConnectionResult", true);
                                } catch (e) {
                                  _addLog('ConnectError (${e.runtimeType})', e);
                                }
                              },
                            ),
                            PlatformButton(
                              text: 'Disconnect',
                              enabled: isConnected,
                              onPressed: () {
                                UniversalBle.disconnect(widget.deviceId);
                              },
                            ),
                          ],
                        ),
                      ),
                      selectedCharacteristic == null
                          ? Text(discoveredServices.isEmpty
                              ? "Please discover services"
                              : "Please select a characteristic")
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Card(
                                child: ListTile(
                                  title: SelectableText(
                                    "Characteristic: ${selectedCharacteristic!.characteristic.uuid}",
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        "Service: ${selectedCharacteristic!.service.uuid}",
                                      ),
                                      Text(
                                        "Properties: ${selectedCharacteristic!.characteristic.properties.map((e) => e.name)}",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                      if (_hasSelectedCharacteristicProperty([
                        CharacteristicProperty.write,
                        CharacteristicProperty.writeWithoutResponse
                      ]))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Form(
                            key: valueFormKey,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: binaryCode,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a value';
                                  }
                                  try {
                                    hex.decode(binaryCode.text);
                                    return null;
                                  } catch (e) {
                                    return 'Please enter a valid hex value ( without spaces or 0x (e.g. F0BB) )';
                                  }
                                },
                                decoration: const InputDecoration(
                                  hintText:
                                      "Enter Hex values without spaces or 0x (e.g. F0BB)",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ResponsiveButtonsGrid(
                          children: [
                            PlatformButton(
                              onPressed: () async {
                                _discoverServices();
                              },
                              enabled: isConnected,
                              text: 'Discover Services',
                            ),
                            PlatformButton(
                              onPressed: () async {
                                _addLog(
                                  'ConnectionState',
                                  await UniversalBle.getConnectionState(
                                    widget.deviceId,
                                  ),
                                );
                              },
                              text: 'Connection State',
                            ),
                            if (BleCapabilities.supportsRequestMtuApi)
                              PlatformButton(
                                enabled: isConnected,
                                onPressed: () async {
                                  int mtu = await UniversalBle.requestMtu(
                                      widget.deviceId, 247);
                                  _addLog('MTU', mtu);
                                },
                                text: 'Request Mtu',
                              ),
                            PlatformButton(
                              enabled: isConnected &&
                                  discoveredServices.isNotEmpty &&
                                  _hasSelectedCharacteristicProperty([
                                    CharacteristicProperty.read,
                                  ]),
                              onPressed: _readValue,
                              text: 'Read',
                            ),
                            PlatformButton(
                              enabled: isConnected &&
                                  discoveredServices.isNotEmpty &&
                                  _hasSelectedCharacteristicProperty([
                                    CharacteristicProperty.write,
                                    CharacteristicProperty.writeWithoutResponse
                                  ]),
                              onPressed: _writeValue,
                              text: 'Write',
                            ),
                            PlatformButton(
                              enabled: isConnected &&
                                  discoveredServices.isNotEmpty &&
                                  _hasSelectedCharacteristicProperty([
                                    CharacteristicProperty.notify,
                                    CharacteristicProperty.indicate
                                  ]),
                              onPressed: () => _setBleInputProperty(
                                  BleInputProperty.notification),
                              text: 'Subscribe',
                            ),
                            PlatformButton(
                              enabled: isConnected &&
                                  discoveredServices.isNotEmpty &&
                                  _hasSelectedCharacteristicProperty([
                                    CharacteristicProperty.notify,
                                    CharacteristicProperty.indicate
                                  ]),
                              onPressed: () => _setBleInputProperty(
                                  BleInputProperty.disabled),
                              text: 'Unsubscribe',
                            ),
                            PlatformButton(
                              enabled: BleCapabilities.supportsAllPairingKinds,
                              onPressed: () async {
                                try {
                                  await UniversalBle.pair(
                                    widget.deviceId,
                                    // pairingCommand: BleCommand(
                                    //   service: "",
                                    //   characteristic: "",
                                    // ),
                                  );
                                  _addLog("Pairing Result", true);
                                } catch (e) {
                                  _addLog('PairError (${e.runtimeType})', e);
                                }
                              },
                              text: 'Pair',
                            ),
                            PlatformButton(
                              onPressed: () async {
                                bool? isPaired = await UniversalBle.isPaired(
                                  widget.deviceId,
                                  // pairingCommand: BleCommand(
                                  //   service: "",
                                  //   characteristic: "",
                                  // ),
                                );
                                _addLog('IsPaired', isPaired);
                              },
                              text: 'IsPaired',
                            ),
                            PlatformButton(
                              onPressed: () async {
                                await UniversalBle.unpair(widget.deviceId);
                              },
                              text: 'Unpair',
                            ),
                          ],
                        ),
                      ),
                      // Services
                      if (deviceType != DeviceType.desktop)
                        ServicesListWidget(
                          discoveredServices: discoveredServices,
                          onTap: (BleService service,
                              BleCharacteristic characteristic) {
                            setState(() {
                              selectedCharacteristic = (
                                service: service,
                                characteristic: characteristic
                              );
                            });
                          },
                        ),
                      const Divider(),
                      ResultWidget(
                          results: _logs,
                          onClearTap: (int? index) {
                            setState(() {
                              if (index != null) {
                                _logs.removeAt(index);
                              } else {
                                _logs.clear();
                              }
                            });
                          }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  bool _hasSelectedCharacteristicProperty(
          List<CharacteristicProperty> properties) =>
      properties.any((property) =>
          selectedCharacteristic?.characteristic.properties
              .contains(property) ??
          false);
}
