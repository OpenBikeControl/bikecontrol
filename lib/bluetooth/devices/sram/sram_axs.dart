import 'dart:async';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class SramAxs extends BluetoothDevice {
  SramAxs(super.scanResult) : super(availableButtons: [], isBeta: true);

  Timer? _singleClickTimer;
  int _tapCount = 0;

  @override
  Future<void> disconnect() async {
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _tapCount = 0;
    await super.disconnect();
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere(
      (e) => e.uuid.toLowerCase() == SramAxsConstants.SERVICE_UUID_RELEVANT.toLowerCase(),
    );

    if (service == null) {
      actionStreamInternal.add(LogNotification('SramAxs: Relevant service not found: ${SramAxsConstants.SERVICE_UUID_RELEVANT}'));
      return;
    }

    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == SramAxsConstants.TRIGGER_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${SramAxsConstants.TRIGGER_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);

    // add both buttons
    _singleClickButton();
    _doubleClickButton();
  }

  ControllerButton _singleClickButton() => getOrAddButton(
    'SRAM Tap',
    () => ControllerButton('SRAM Tap', action: InGameAction.shiftUp, sourceDeviceId: device.deviceId),
  );

  ControllerButton _doubleClickButton() => getOrAddButton(
    'SRAM Double Tap',
    () => ControllerButton('SRAM Double Tap', action: InGameAction.shiftDown, sourceDeviceId: device.deviceId),
  );

  void _emitClick(ControllerButton button) {
    // Use the common pipeline so long-press handling and app action execution stays consistent.
    handleButtonsClickedWithoutLongPressSupport([button]);
  }

  void _registerTap() {
    final windowMs = core.settings.getSramAxsDoubleClickWindowMs();

    _tapCount++;

    // First tap: start a timer. If no second tap arrives in time => single click.
    if (_tapCount == 1) {
      _singleClickTimer?.cancel();
      _singleClickTimer = Timer(Duration(milliseconds: windowMs), () {
        if (_tapCount == 1) {
          _emitClick(_singleClickButton());
        }
        _tapCount = 0;
      });
      return;
    }

    // Second tap within window: double click.
    if (_tapCount == 2) {
      _singleClickTimer?.cancel();
      _singleClickTimer = null;
      _emitClick(_doubleClickButton());
      _tapCount = 0;
      return;
    }

    // If we get more than two taps fast, treat as a double click and restart counting.
    _singleClickTimer?.cancel();
    _singleClickTimer = null;
    _emitClick(_doubleClickButton());
    _tapCount = 0;
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (kDebugMode) {
      debugPrint('SramAxs: Received data on characteristic $characteristic: ${bytesToHex(bytes)}');
    }

    if (characteristic.toLowerCase() == SramAxsConstants.TRIGGER_UUID.toLowerCase()) {
      // At the moment we can only detect "some button pressed". We therefore interpret each
      // notification as a tap and provide two logical buttons (single & double click).
      _registerTap();
    }

    return Future.value();
  }

  @override
  Widget showInformation(BuildContext context) {
    final windowMs = core.settings.getSramAxsDoubleClickWindowMs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        super.showInformation(context),
        Text(
          "Don't forget to turn off the function of the button you want to use in the SRAM AXS app!\n"
          "Unfortunately, at the moment it's not possible to determine which physical button was pressed on your SRAM AXS device. Let us know if you have a contact at SRAM who can help :)\n\n"
          'So the app exposes two logical buttons:\n'
          '• SRAM Tap, assigned to Shift Up\n'
          '• SRAM Double Tap, assigned to Shift Down\n\n'
          'You can assign an action to each in the app settings.',
        ).xSmall,
        Builder(
          builder: (context) {
            return PrimaryButton(
              size: ButtonSize.small,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${windowMs}ms'),
              ),
              onPressed: () {
                final values = [
                  for (var v = 150; v <= 600; v += 50) v,
                ];
                showDropdown(
                  context: context,
                  builder: (b) => DropdownMenu(
                    children: values
                        .map(
                          (v) => MenuButton(
                            child: Text('${v}ms'),
                            onPressed: (c) async {
                              await core.settings.setSramAxsDoubleClickWindowMs(v);
                              // Force rebuild to show new value.
                              (context as Element).markNeedsBuild();
                            },
                          ),
                        )
                        .toList(),
                  ),
                );
              },
              child: const Text('Double-click window:'),
            );
          },
        ),
      ],
    );
  }
}

class SramAxsConstants {
  static const String SERVICE_UUID = "0000fe51-0000-1000-8000-00805f9b34fb";
  static const String SERVICE_UUID_RELEVANT = "d9050053-90aa-4c7c-b036-1e01fb8eb7ee";

  static const String TRIGGER_UUID = "d9050054-90aa-4c7c-b036-1e01fb8eb7ee";
}
