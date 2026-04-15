import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID, // Heart Rate
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, // Heart Rate
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, // Fitness Machine
  ];

  final DirconEmulator emulator = DirconEmulator();
  RetrofitMode _pendingMode = RetrofitMode.proxy;

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        isBeta: true,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    emulator.setScanResult(scanResult);
    emulator.handleServices(services);

    emulator.startServer();
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  Widget showInformation(BuildContext context, {required bool showFull}) {
    return Column(
      children: [
        Row(
          spacing: 16,
          children: [
            Expanded(child: super.showInformation(context, showFull: showFull)),
            if (!isConnected) ...[
              StatefulBuilder(
                builder: (context, setLocalState) {
                  var pending = _pendingMode;
                  final allowedModes = [
                    RetrofitMode.proxy,
                    if (scanResult.services.any((s) => s == FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID))
                      RetrofitMode.wifi,
                    RetrofitMode.bluetooth,
                  ];
                  return Row(
                    spacing: 8,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Select<RetrofitMode>(
                        value: pending,
                        itemBuilder: (context, value) => Text(value.label ?? ''),
                        constraints: BoxConstraints(minWidth: 200),
                        popup: SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (final m in allowedModes) SelectItemButton(value: m, child: Text(m.label)),
                            ],
                          ),
                        ).call,
                        onChanged: (m) {
                          if (m == null) return;
                          setLocalState(() {
                            _pendingMode = m;
                          });
                        },
                      ),
                      Button.primary(
                        style: ButtonStyle.primary(size: ButtonSize.small),
                        onPressed: () {
                          emulator.setRetrofitMode(_pendingMode);
                          super.connect();
                        },
                        child: const Text('Connect'),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              if (kDebugMode)
                Button.primary(
                  style: ButtonStyle.primary(size: ButtonSize.small),
                  onPressed: () async {
                    await emulator.debug();
                  },
                  child: Text('Debug'),
                ),
              StatusIcon(
                status: emulator.isConnected.value,
                icon: Icons.wifi,
                started: emulator.isStarted.value,
              ),
            ],
          ],
        ),
        if (isConnected)
          ValueListenableBuilder(
            valueListenable: emulator.data,
            builder: (context, value, child) {
              return value.isNotEmpty ? Text('Data: $value') : const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() {
    emulator.stop();
    return super.disconnect();
  }
}
