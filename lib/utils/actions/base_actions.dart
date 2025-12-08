import 'dart:io';
import 'dart:math';

import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/gen/l10n.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

import '../keymap/apps/supported_app.dart';

enum SupportedMode { keyboard, touch, media }

sealed class ActionResult {
  final String message;
  const ActionResult(this.message);
}

class Success extends ActionResult {
  const Success(super.message);
}

class NotHandled extends ActionResult {
  const NotHandled(super.message);
}

class Error extends ActionResult {
  const Error(super.message);
}

abstract class BaseActions {
  final List<SupportedMode> supportedModes;

  SupportedApp? supportedApp;

  BaseActions({required this.supportedModes});

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
    print('Supported app: ${supportedApp?.name ?? "None"}');

    if (supportedApp != null) {
      final allButtons = core.connection.devices.map((e) => e.availableButtons).flatten().distinct();

      final newButtons = allButtons.filter(
        (button) => supportedApp.keymap.getKeyPair(button) == null,
      );
      for (final button in newButtons) {
        supportedApp.keymap.addKeyPair(
          KeyPair(
            touchPosition: Offset.zero,
            buttons: [button],
            physicalKey: null,
            logicalKey: null,
            isLongPress: false,
          ),
        );
      }
    }
  }

  Future<Offset> resolveTouchPosition({required KeyPair keyPair, required WindowEvent? windowInfo}) async {
    if (keyPair.touchPosition != Offset.zero) {
      // convert relative position to absolute position based on window info

      // TODO support multiple screens
      final Size displaySize;
      final double devicePixelRatio;
      if (Platform.isWindows) {
        // TODO remove once https://github.com/flutter/flutter/pull/164460 is available in stable
        final display = await screenRetriever.getPrimaryDisplay();
        displaySize = display.size;
        devicePixelRatio = 1.0;
      } else {
        final display = WidgetsBinding.instance.platformDispatcher.views.first.display;
        displaySize = display.size;
        devicePixelRatio = display.devicePixelRatio;
      }

      late final Size physicalSize;
      if (this is AndroidActions) {
        if (windowInfo != null && windowInfo.packageName != 'de.jonasbark.swiftcontrol') {
          // a trainer app is in foreground, so use the always assume landscape
          physicalSize = Size(max(displaySize.width, displaySize.height), min(displaySize.width, displaySize.height));
        } else {
          // display size is already in physical pixels
          physicalSize = displaySize;
        }
      } else if (this is DesktopActions) {
        // display size is in logical pixels, convert to physical pixels
        // TODO on macOS the notch is included here, but it's not part of the usable screen area, so we should exclude it
        physicalSize = displaySize / devicePixelRatio;
      } else {
        physicalSize = displaySize;
      }

      final x = (keyPair.touchPosition.dx / 100.0) * physicalSize.width;
      final y = (keyPair.touchPosition.dy / 100.0) * physicalSize.height;

      if (kDebugMode) {
        print("Screen size: $physicalSize vs $displaySize => Touch at: $x, $y");
      }
      return Offset(x, y);
    }
    return Offset.zero;
  }

  Future<ActionResult> performAction(ControllerButton button, {required bool isKeyDown, required bool isKeyUp}) async {
    if (supportedApp == null) {
      return Error("Could not perform ${button.name.splitByUpperCase()}: No keymap set");
    }

    final keyPair = supportedApp!.keymap.getKeyPair(button);

    if (core.logic.hasNoConnectionMethod) {
      return Error(AppLocalizations.current.pleaseSelectAConnectionMethodFirst);
    } else if (!(await core.logic.isTrainerConnected())) {
      return Error('No connection method is connected or active.');
    } else if (keyPair == null) {
      return Error("Could not perform ${button.name.splitByUpperCase()}: No action assigned");
    } else if (keyPair.hasNoAction) {
      return Error('No action assigned for ${button.toString().splitByUpperCase()}');
    }

    final directConnectHandled = await _handleDirectConnect(keyPair, button, isKeyUp: isKeyUp, isKeyDown: isKeyDown);
    if (directConnectHandled is NotHandled && directConnectHandled.message.isNotEmpty) {
      core.connection.signalNotification(LogNotification(directConnectHandled.message));
    }
    return directConnectHandled;
  }

  Future<ActionResult> _handleDirectConnect(
    KeyPair keyPair,
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
  }) async {
    if (keyPair.inGameAction != null) {
      // Handle Headwind actions
      if (keyPair.inGameAction == InGameAction.headwindSpeed || 
          keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
        final WahooKickrHeadwind? headwind = core.connection.accessories.firstOrNull;
        if (headwind != null && isKeyDown) {
          try {
            if (keyPair.inGameAction == InGameAction.headwindSpeed) {
              final speed = keyPair.inGameActionValue ?? 0;
              await headwind.setSpeed(speed);
              return Success('Headwind speed set to $speed%');
            } else if (keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
              await headwind.setHeartRateMode();
              return Success('Headwind set to Heart Rate mode');
            }
          } catch (e) {
            return Error('Failed to control Headwind: $e');
          }
        }
        return Error('No Headwind connected');
      }

      if (core.obpBluetoothEmulator.isConnected.value != null) {
        return core.obpBluetoothEmulator.sendButtonPress(
          [button],
          isKeyDown: isKeyDown,
          isKeyUp: isKeyUp,
        );
      } else if (core.obpMdnsEmulator.isConnected.value != null) {
        return Future.value(
          core.obpMdnsEmulator.sendButtonPress(
            [button],
            isKeyDown: isKeyDown,
            isKeyUp: isKeyUp,
          ),
        );
      } else if (core.whooshLink.isConnected.value) {
        return Future.value(
          core.whooshLink.sendAction(
            keyPair.inGameAction!,
            keyPair.inGameActionValue,
            isKeyDown: isKeyDown,
            isKeyUp: isKeyUp,
          ),
        );
      } else if (core.zwiftMdnsEmulator.isConnected.value) {
        return core.zwiftMdnsEmulator.sendAction(
          keyPair.inGameAction!,
          keyPair.inGameActionValue,
          isKeyDown: isKeyDown,
          isKeyUp: isKeyUp,
        );
      } else if (core.zwiftEmulator.isConnected.value) {
        return core.zwiftEmulator.sendAction(
          keyPair.inGameAction!,
          keyPair.inGameActionValue,
          isKeyDown: isKeyDown,
          isKeyUp: isKeyUp,
        );
      }
    }
    return NotHandled('');
  }
}

class StubActions extends BaseActions {
  StubActions({super.supportedModes = const []});

  final List<ControllerButton> performedActions = [];

  @override
  Future<ActionResult> performAction(ControllerButton button, {bool isKeyDown = true, bool isKeyUp = false}) async {
    performedActions.add(button);
    return Future.value(Success('${button.name.splitByUpperCase()} clicked'));
  }
}
