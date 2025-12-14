import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';

import '../keymap.dart';

class Rouvy extends SupportedApp {
  Rouvy()
    : super(
        name: 'Rouvy',
        packageName: "eu.virtualtraining.rouvy.android",
        compatibleTargets: !kIsWeb && Platform.isIOS ? [Target.otherDevice] : Target.values,
        supportsZwiftEmulation: !kIsWeb && Platform.isAndroid,
        keymap: Keymap(
          keyPairs: [
            // https://support.rouvy.com/hc/de/articles/32452137189393-Virtuelles-Schalten#h_01K5GMVG4KVYZ0Y6W7RBRZC9MA
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftDown)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    inGameAction: InGameAction.shiftDown,
                    physicalKey: PhysicalKeyboardKey.comma,
                    logicalKey: LogicalKeyboardKey.comma,
                    touchPosition: Offset(94, 80),
                  ),
                ),
            ...ControllerButton.values
                .filter((e) => e.action == InGameAction.shiftUp)
                .map(
                  (b) => KeyPair(
                    buttons: [b],
                    inGameAction: InGameAction.shiftUp,
                    physicalKey: PhysicalKeyboardKey.period,
                    logicalKey: LogicalKeyboardKey.period,
                    touchPosition: Offset(94, 72),
                  ),
                ),
            // like escape
            KeyPair(
              buttons: [ZwiftButtons.b],
              physicalKey: PhysicalKeyboardKey.keyB,
              logicalKey: LogicalKeyboardKey.keyB,
              inGameAction: InGameAction.back,
            ),
          ],
        ),
      );
}
