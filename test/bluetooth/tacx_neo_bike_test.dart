import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/tacx/tacx_neo_bike.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

/// Records what the decoder hands to the shared press/release handling,
/// instead of running it.
class _RecordingBike extends TacxNeoBike {
  _RecordingBike() : super(BleDevice(deviceId: 'neo-bike', name: 'Tacx Neo Bike 12345'));

  final calls = <List<ControllerButton>>[];

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    calls.add(List.of(buttonsClicked ?? const []));
  }
}

Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  core.actionHandler = StubActions();

  group('TacxGearStatus.parse', () {
    test('both gears', () {
      final s = TacxGearStatus.parse(b([0x03, 50, 17]))!;
      expect(s.front, 50);
      expect(s.rear, 17);
    });
    test('front only / rear only', () {
      expect(TacxGearStatus.parse(b([0x01, 34]))!.rear, isNull);
      expect(TacxGearStatus.parse(b([0x01, 34]))!.front, 34);
      expect(TacxGearStatus.parse(b([0x02, 21]))!.front, isNull);
      expect(TacxGearStatus.parse(b([0x02, 21]))!.rear, 21);
    });
    test('garbage is ignored, never thrown on', () {
      for (final bytes in [
        <int>[],
        [0x00],
        [0x00, 0x11],
        [0x01],
        [0x02],
        [0x03, 0x22],
      ]) {
        expect(TacxGearStatus.parse(b(bytes)), isNull, reason: '$bytes');
      }
    });
  });

  group('TacxButtonStatus.parse', () {
    test('bit 7 is pressed', () {
      final s = TacxButtonStatus.parse(b([0x03, 0x80, 0x00]))!;
      expect(s.left, isTrue);
      expect(s.right, isFalse);
    });
    test('a side the flags leave out is unknown', () {
      final s = TacxButtonStatus.parse(b([0x02, 0x80]))!;
      expect(s.left, isNull);
      expect(s.right, isTrue);
    });
    test('garbage is ignored', () {
      for (final bytes in [
        <int>[],
        [0x00, 0x80],
        [0x01],
        [0x03, 0x80],
      ]) {
        expect(TacxButtonStatus.parse(b(bytes)), isNull, reason: '$bytes');
      }
    });
  });

  group('TacxControlPointResponse', () {
    test('a gear table response', () {
      final r = TacxControlPointResponse.parse(b([0x20, 0x05, 0x01, 3, 11, 13, 15]))!;
      expect(r.opcode, 5);
      expect(r.isSuccess, isTrue);
      expect(r.gearTable, [11, 13, 15]);
    });
    test('a count larger than the frame takes what is there', () {
      expect(TacxControlPointResponse.parse(b([0x20, 0x04, 0x01, 5, 34, 50]))!.gearTable, [34, 50]);
    });
    test('a failed request', () {
      expect(TacxControlPointResponse.parse(b([0x20, 0x04, 0x02]))!.isSuccess, isFalse);
    });
    test('not a response', () {
      expect(TacxControlPointResponse.parse(b([0x04, 0x05, 0x01])), isNull);
      expect(TacxControlPointResponse.parse(b([0x20, 0x04])), isNull);
    });
  });

  group('TacxShiftDetector', () {
    test('the first gear seen is no shift', () {
      expect(TacxShiftDetector().update(front: 50, rear: 17), isEmpty);
    });

    test('fewer teeth at the rear is harder, more is easier', () {
      final d = TacxShiftDetector()..update(front: 50, rear: 17);
      expect(d.update(rear: 15), [TacxNeoBikeButtons.rearUp]);
      expect(d.update(rear: 17), [TacxNeoBikeButtons.rearDown]);
      expect(d.update(rear: 17), isEmpty, reason: 'a repeated status is no shift');
    });

    test('more teeth at the front is harder', () {
      final d = TacxShiftDetector()..update(front: 34, rear: 17);
      expect(d.update(front: 50), [TacxNeoBikeButtons.frontUp]);
      expect(d.update(front: 34), [TacxNeoBikeButtons.frontDown]);
    });

    test('with the table a jump of several gears is several presses', () {
      final d = TacxShiftDetector()
        ..rearTable = [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30]
        ..update(front: 50, rear: 17);
      expect(d.update(rear: 13), List.filled(3, TacxNeoBikeButtons.rearUp));
      expect(d.update(rear: 21), List.filled(5, TacxNeoBikeButtons.rearDown));
    });

    test('a value missing from the table is one press', () {
      final d = TacxShiftDetector()
        ..rearTable = [11, 13, 15]
        ..update(rear: 13);
      expect(d.update(rear: 99), [TacxNeoBikeButtons.rearDown]);
    });

    test('reset forgets the start gear', () {
      final d = TacxShiftDetector()..update(front: 50, rear: 17);
      d.reset();
      expect(d.update(front: 34, rear: 21), isEmpty);
    });
  });

  group('TacxNeoBike notifications', () {
    test('a rear shift is one press and release', () async {
      final bike = _RecordingBike();
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x03, 50, 17]));
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x03, 50, 17]));
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x03, 50, 15]));
      expect(bike.calls, [
        [TacxNeoBikeButtons.rearUp],
        <ControllerButton>[],
      ]);
    });

    test('characteristic uuids match case-insensitively', () async {
      final bike = _RecordingBike();
      final upper = TacxNeoBikeConstants.GEAR_STATUS_UUID.toUpperCase();
      await bike.processCharacteristic(upper, b([0x03, 34, 21]));
      await bike.processCharacteristic(upper, b([0x03, 50, 21]));
      expect(bike.calls.first, [TacxNeoBikeButtons.frontUp]);
    });

    test('the gear tables from the control point turn jumps into several presses', () async {
      final bike = _RecordingBike();
      await bike.processCharacteristic(
        TacxNeoBikeConstants.CONTROL_POINT_UUID,
        b([0x20, 0x05, 0x01, 5, 11, 13, 15, 17, 19]),
      );
      expect(bike.shiftDetector.rearTable, [11, 13, 15, 17, 19]);
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x02, 19]));
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x02, 15]));
      expect(bike.calls.where((c) => c.isNotEmpty), List.filled(2, [TacxNeoBikeButtons.rearUp]));
    });

    test('side buttons press while held and release once', () async {
      final bike = _RecordingBike();
      await bike.processCharacteristic(TacxNeoBikeConstants.BUTTONS_UUID, b([0x03, 0x80, 0x00]));
      await bike.processCharacteristic(TacxNeoBikeConstants.BUTTONS_UUID, b([0x03, 0x80, 0x00]));
      await bike.processCharacteristic(TacxNeoBikeConstants.BUTTONS_UUID, b([0x03, 0x00, 0x00]));
      await bike.processCharacteristic(TacxNeoBikeConstants.BUTTONS_UUID, b([0x03, 0x00, 0x80]));
      await bike.processCharacteristic(TacxNeoBikeConstants.BUTTONS_UUID, b([0x03, 0x00, 0x00]));
      expect(bike.calls, [
        [TacxNeoBikeButtons.leftButton],
        <ControllerButton>[],
        [TacxNeoBikeButtons.rightButton],
        <ControllerButton>[],
      ]);
    });

    // Frames recorded on a real NEO Bike Smart (fw 4.5.0): the rear table
    // comes largest cog first, and a shift is a frame with only that gear.
    test('a real bike: one lever press is one shift each way', () async {
      final bike = _RecordingBike();
      await bike.processCharacteristic(
        TacxNeoBikeConstants.CONTROL_POINT_UUID,
        b([0x20, 0x04, 0x01, 0x02, 0x22, 0x32]),
      );
      await bike.processCharacteristic(
        TacxNeoBikeConstants.CONTROL_POINT_UUID,
        b([0x20, 0x05, 0x01, 0x0b, 0x20, 0x1c, 0x19, 0x16, 0x14, 0x12, 0x10, 0x0e, 0x0d, 0x0c, 0x0b]),
      );
      for (final frame in [
        [0x03, 0x32, 0x14],
        [0x02, 0x12],
        [0x03, 0x32, 0x12],
        [0x02, 0x14],
        [0x03, 0x32, 0x14],
        [0x01, 0x22],
        [0x01, 0x32],
        [0x03, 0x32, 0x14],
      ]) {
        await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b(frame));
      }
      expect(bike.calls.where((c) => c.isNotEmpty), [
        [TacxNeoBikeButtons.rearUp],
        [TacxNeoBikeButtons.rearDown],
        [TacxNeoBikeButtons.frontDown],
        [TacxNeoBikeButtons.frontUp],
      ]);
    });

    test('the repeated no-error frame stops being logged', () async {
      final bike = _RecordingBike();
      final logs = <String>[];
      final sub = bike.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      for (var i = 0; i < 100; i++) {
        await bike.processCharacteristic(TacxNeoBikeConstants.ERRORS_UUID, b([0x01, 0x00, 0x00]));
      }
      await bike.processCharacteristic(TacxNeoBikeConstants.ERRORS_UUID, b([0x01, 0x05, 0x00]));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(logs.where((l) => l.contains('error/diagnostic frame 01 00 00')), hasLength(20));
      expect(logs, contains(contains('error/diagnostic frame 01 05 00')));
    });

    test('every vendor frame is logged; a repeated one only at first', () async {
      final bike = _RecordingBike();
      final logs = <String>[];
      final sub = bike.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      for (var i = 0; i < 30; i++) {
        await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x03, 50, 17]));
      }
      await bike.processCharacteristic(TacxNeoBikeConstants.GEAR_STATUS_UUID, b([0x03, 50, 15]));
      await bike.processCharacteristic(TacxNeoBikeConstants.FEATURES_UUID, b([0x87, 0x00]));
      await bike.processCharacteristic(TacxNeoBikeConstants.ERRORS_UUID, b([0x01, 0x05, 0x00]));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(logs.where((l) => l.contains('gears #')), hasLength(21));
      expect(logs, contains(contains('gears #31 03 32 0f')));
      expect(logs, contains(contains('tacxRearUp')));
      expect(logs, contains(contains('features 0x87: errors, gear status, buttons, gear tables')));
      expect(logs, contains(contains('error/diagnostic frame 01 05 00')));
    });
  });

  group('detection', () {
    BleDevice scan(String name, {List<String> services = const []}) =>
        BleDevice(deviceId: 'id-$name', name: name, services: services);
    final ftms = [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase()];

    for (final name in ['Tacx Neo Bike 12345', 'TACX NEO BIKE', 'NEO Bike Plus 01234', 'Tacx Smart Bike 0001']) {
      test('"$name" is the bike', () {
        expect(BluetoothDevice.fromScanResult(scan(name, services: ftms)), isA<TacxNeoBike>());
      });
    }

    for (final name in ['Tacx Neo 2T 53426', 'NEO 2T 09646', 'Tacx Neo 3M 1234', 'Tacx Flux 60510']) {
      test('"$name" stays a trainer', () {
        final device = BluetoothDevice.fromScanResult(scan(name, services: ftms));
        expect(device, isA<ProxyDevice>());
        expect(device, isNot(isA<TacxNeoBike>()));
      });
    }

    test('support intake files it under other', () {
      expect(controllerOptionIdFor(TacxNeoBike(scan('Tacx Neo Bike 1'))), 'other');
    });

    test('its buttons are known to the keymap', () {
      for (final button in TacxNeoBikeButtons.values) {
        expect(ControllerButton.values, contains(button));
      }
    });
  });
}
