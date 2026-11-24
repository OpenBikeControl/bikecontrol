// A Zwift Play / Ride paddle tilts two ways. Each direction is its own
// button, decided by the sign of the analog value (see [ZwiftPaddle]).
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play_fw2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/emulation/profiles/zwift_profiles.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('ZwiftPaddle sign mapping', () {
    test('inward: left positive, right negative; outward the opposite', () {
      expect(ZwiftPaddle.value(right: false, inward: true), 100);
      expect(ZwiftPaddle.value(right: true, inward: true), -100);
      expect(ZwiftPaddle.value(right: false, inward: false), -100);
      expect(ZwiftPaddle.value(right: true, inward: false), 100);
    });

    test('button for a value is the inverse of value()', () {
      for (final right in [false, true]) {
        for (final inward in [false, true]) {
          final button = ZwiftPaddle.button(right: right, value: ZwiftPaddle.value(right: right, inward: inward));
          expect(button, ZwiftPaddle.buttonFor(right: right, inward: inward));
        }
      }
    });
  });

  group('Zwift Play', () {
    final left = ZwiftPlay(BleDevice(name: 'Zwift Play', deviceId: 'l'), deviceType: ZwiftDeviceType.playLeft);
    final right = ZwiftPlay(BleDevice(name: 'Zwift Play', deviceId: 'r'), deviceType: ZwiftDeviceType.playRight);

    List<ControllerButton> press(ZwiftPlay device, int analogLR) => device.processClickNotification(
      Uint8List.fromList(
        zwiftPlayNotification(rightPad: device == right, analogLR: analogLR).sublist(1),
      ),
    );

    test('left paddle: positive is inward, negative outward', () {
      expect(press(left, 100), [ZwiftButtons.paddleLeftInward]);
      expect(press(left, -100), [ZwiftButtons.paddleLeftOutward]);
    });

    test('right paddle: negative is inward, positive outward', () {
      expect(press(right, -100), [ZwiftButtons.paddleRightInward]);
      expect(press(right, 100), [ZwiftButtons.paddleRightOutward]);
    });

    test('below a full deflection nothing is pressed', () {
      expect(press(left, 99), isEmpty);
      expect(press(left, -50), isEmpty);
      expect(press(right, 0), isEmpty);
    });

    test('each pod offers both directions of its own paddle', () {
      expect(left.availableButtons, containsAll([ZwiftButtons.paddleLeftInward, ZwiftButtons.paddleLeftOutward]));
      expect(right.availableButtons, containsAll([ZwiftButtons.paddleRightInward, ZwiftButtons.paddleRightOutward]));
    });

    test('every offered button has a place on the pod', () {
      for (final pod in [left, right]) {
        for (final button in pod.availableButtons) {
          expect(pod.controllerLayout.positions, contains(button), reason: '$pod: $button');
        }
      }
    });
  });

  group('Zwift Ride / Play firmware 2', () {
    final ride = ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'ride'));
    final playFw2 = ZwiftPlayFw2(BleDevice(name: 'Zwift Play', deviceId: 'fw2'));

    List<ControllerButton> press(ZwiftRide device, RideAnalogLocation location, int value) {
      final status = RideKeyPadStatus(buttonMap: 0xFFFFFFFF)
        ..analogPaddles.add(RideAnalogKeyPress(location: location, analogValue: value));
      return device.processClickNotification(Uint8List.fromList(status.writeToBuffer()));
    }

    for (final device in [ride, playFw2]) {
      test('${device.runtimeType}: location × sign → direction', () {
        expect(press(device, RideAnalogLocation.LEFT, 60), [ZwiftButtons.paddleLeftInward]);
        expect(press(device, RideAnalogLocation.LEFT, -60), [ZwiftButtons.paddleLeftOutward]);
        expect(press(device, RideAnalogLocation.RIGHT, -60), [ZwiftButtons.paddleRightInward]);
        expect(press(device, RideAnalogLocation.RIGHT, 60), [ZwiftButtons.paddleRightOutward]);
      });

      test('${device.runtimeType}: the threshold still holds', () {
        expect(press(device, RideAnalogLocation.LEFT, ZwiftRide.analogPaddleThreshold), isNotEmpty);
        expect(press(device, RideAnalogLocation.LEFT, ZwiftRide.analogPaddleThreshold - 1), isEmpty);
        expect(press(device, RideAnalogLocation.RIGHT, -(ZwiftRide.analogPaddleThreshold - 1)), isEmpty);
      });

      test('${device.runtimeType}: offers all four paddle directions, each placed', () {
        final paddles = [
          ZwiftButtons.paddleLeftInward,
          ZwiftButtons.paddleLeftOutward,
          ZwiftButtons.paddleRightInward,
          ZwiftButtons.paddleRightOutward,
        ];
        expect(device.availableButtons, containsAll(paddles));
        for (final button in device.availableButtons) {
          expect(device.controllerLayout.positions, contains(button), reason: '$button');
        }
      });
    }
  });

  group('the four paddle buttons', () {
    test('keep the old defaults: left shifts down, right shifts up', () {
      expect(ZwiftButtons.paddleLeftInward.action, InGameAction.shiftDown);
      expect(ZwiftButtons.paddleLeftOutward.action, InGameAction.shiftDown);
      expect(ZwiftButtons.paddleRightInward.action, InGameAction.shiftUp);
      expect(ZwiftButtons.paddleRightOutward.action, InGameAction.shiftUp);
    });

    test('read well and look different', () {
      expect(ZwiftButtons.paddleLeftInward.displayName, 'Paddle Left Inward');
      expect(ZwiftButtons.paddleRightOutward.displayName, 'Paddle Right Outward');
      final labels = {
        ZwiftButtons.paddleLeftInward.shortLabel,
        ZwiftButtons.paddleLeftOutward.shortLabel,
      };
      expect(labels, hasLength(2));
      expect(ZwiftButtons.values, isNot(contains(predicate<ControllerButton>((b) => b.name == 'paddleLeft'))));
    });
  });
}
