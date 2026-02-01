import 'dart:io';
import 'dart:math';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/desktop.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

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

class Ignored extends ActionResult {
  const Ignored(super.message);
}

class Error extends ActionResult {
  const Error(super.message);
}

abstract class BaseActions {
  final List<SupportedMode> supportedModes;

  SupportedApp? supportedApp;

  BaseActions({required this.supportedModes});

  void cleanup();

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
    debugPrint('Supported app: ${supportedApp?.name ?? "None"}');

    if (supportedApp != null) {
      final allButtons = core.connection.devices.map((e) => e.availableButtons).flatten().distinct().toList();
      supportedApp.keymap.addNewButtons(allButtons);
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
      return Error(
        AppLocalizations.current.couldNotPerformButtonnamesplitbyuppercaseNoKeymapSet(button.name.splitByUpperCase()),
      );
    }

    final keyPair = supportedApp!.keymap.getKeyPair(button);

    if (core.logic.hasNoConnectionMethod) {
      if (GyroscopeSteeringButtons.values.contains(button)) {
        return Ignored('Too many messages from gyroscope steering');
      } else {
        return Error(AppLocalizations.current.pleaseSelectAConnectionMethodFirst);
      }
    } else if (!(await core.logic.isTrainerConnected())) {
      return Error(AppLocalizations.current.noConnectionMethodIsConnectedOrActive);
    } else if (keyPair == null || keyPair.hasNoAction) {
      return Error(AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()));
    }

    // Handle Headwind actions
    if (keyPair.inGameAction == InGameAction.headwindSpeed ||
        keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
      final headwind = core.connection.accessories.where((h) => h.isConnected).firstOrNull;
      if (headwind == null) {
        return Error('No Headwind connected');
      }

      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return await headwind.handleKeypair(keyPair, isKeyDown: isKeyDown);
    }

    final directConnectHandled = await _handleDirectConnect(keyPair, button, isKeyUp: isKeyUp, isKeyDown: isKeyDown);
    if (directConnectHandled is NotHandled && directConnectHandled.message.isNotEmpty) {
      core.connection.signalNotification(LogNotification(directConnectHandled.message));
    } else if (directConnectHandled is! NotHandled) {
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
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
      final actions = <ActionResult>[];
      for (final connectedTrainer in core.logic.connectedTrainerConnections) {
        final result = await connectedTrainer.sendAction(
          keyPair,
          isKeyDown: isKeyDown,
          isKeyUp: isKeyUp,
        );
        actions.add(result);
      }
      if (actions.isNotEmpty) {
        return actions.first;
      }
    }
    return NotHandled('');
  }
}

class StubActions extends BaseActions {
  StubActions({super.supportedModes = const []});

  final List<(ControllerButton button, bool isDown, bool isUp)> performedActions = [];

  @override
  Future<ActionResult> performAction(ControllerButton button, {bool isKeyDown = true, bool isKeyUp = false}) async {
    performedActions.add((button, isKeyDown, isKeyUp));
    return Future.value(Ignored('${button.name.splitByUpperCase()} clicked'));
  }

  @override
  void cleanup() {}
}
