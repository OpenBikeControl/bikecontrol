import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screen_capture/flutter_screen_capture.dart';
import 'package:image/image.dart' as image_lib;
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DesktopActions extends BaseActions {
  DesktopActions({super.supportedModes = const [SupportedMode.keyboard, SupportedMode.touch, SupportedMode.media]});

  // Track keys that are currently held down in long press mode

  @override
  Future<ActionResult> performAction(
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp, trigger: trigger);
    if (superResult is! NotHandled) {
      return superResult;
    }
    final keyPair = supportedApp!.keymap.getKeyPair(button, trigger: trigger)!;

    if (keyPair.screenshotPath?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored('Screenshot capture only runs on key down');
      }

      final screenshotDirectory = keyPair.screenshotPath!.trim();
      try {
        final capturedArea = await ScreenCapture().captureEntireScreen();
        if (capturedArea == null) {
          return Error('Failed to capture screenshot');
        }

        final directory = Directory(screenshotDirectory);

        final timestamp = DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
        final fileName = 'BikeControl $timestamp.jpg';
        final separator = directory.path.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator;
        final screenshotFile = File('${directory.path}$separator$fileName');
        screenshotFile.writeAsBytes(image_lib.encodeJpg(capturedArea.toImage()), flush: true);
        await IAPManager.instance.incrementCommandCount();
        return Success('Screenshot saved: ${screenshotFile.path}');
      } catch (e) {
        return Error('Failed to save screenshot: $e');
      }
    }

    if (keyPair.command?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored('Shortcut launch only runs on key down');
      }

      final commandPath = keyPair.command!.trim();
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final launched = await launchUrlString('shortcuts://run-shortcut?name=$commandPath');
        if (!launched) {
          return Error('Failed to launch shortcut: ${keyPair.command}');
        }
        await IAPManager.instance.incrementCommandCount();
        return Success('Shortcut launched: ${keyPair.command}');
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        try {
          final process = await Process.start(commandPath, const [], runInShell: true);
          process.stderr.transform(const Utf8Decoder()).transform(const LineSplitter()).listen((line) {
            core.connection.signalNotification(LogNotification('Command error: $line'));
          });
        } catch (e) {
          return Error('Failed to run command: $e');
        }
        await IAPManager.instance.incrementCommandCount();
        return Success('Command launched: $commandPath');
      }
    }

    if (core.settings.getLocalEnabled()) {
      // Handle media keys
      if (keyPair.isSpecialKey) {
        try {
          await keyPressSimulator.simulateMediaKey(keyPair.physicalKey!);
          // Increment command count after successful execution
          await IAPManager.instance.incrementCommandCount();
          return Success('Media key pressed: $keyPair');
        } catch (e) {
          return Error('Failed to simulate media key: $e');
        }
      }

      if (keyPair.physicalKey != null) {
        // Increment command count after successful execution
        await IAPManager.instance.incrementCommandCount();
        final trainerApp = core.settings.getTrainerApp();
        // only those two seem to support targeting specific PIDs, for the rest we just send the key events globally
        final packageName = (trainerApp is Rouvy || trainerApp is MyWhoosh) ? trainerApp!.packageName : null;

        if (isKeyDown && isKeyUp) {
          await keyPressSimulator.simulateKeyDown(
            keyPair.physicalKey,
            keyPair.modifiers,
            packageName,
          );
          await keyPressSimulator.simulateKeyUp(
            keyPair.physicalKey,
            keyPair.modifiers,
            packageName,
          );

          return Success('Key clicked: $keyPair');
        } else if (isKeyDown) {
          await keyPressSimulator.simulateKeyDown(
            keyPair.physicalKey,
            keyPair.modifiers,
            core.settings.getTrainerApp()?.name,
          );
          return Success('Key pressed: $keyPair');
        } else {
          await keyPressSimulator.simulateKeyUp(
            keyPair.physicalKey,
            keyPair.modifiers,
            core.settings.getTrainerApp()?.name,
          );
          return Success('Key released: $keyPair');
        }
      } else {
        final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: null);
        if (point != Offset.zero) {
          // Increment command count after successful execution
          await IAPManager.instance.incrementCommandCount();
          if (isKeyDown && isKeyUp) {
            await keyPressSimulator.simulateMouseClickDown(point);
            // slight move to register clicks on some apps, see issue #116
            await keyPressSimulator.simulateMouseClickUp(point);
            return Success('Mouse clicked at: ${point.dx.toInt()} ${point.dy.toInt()}');
          } else if (isKeyDown) {
            await keyPressSimulator.simulateMouseClickDown(point);
            return Success('Mouse down at: ${point.dx.toInt()} ${point.dy.toInt()}');
          } else {
            await keyPressSimulator.simulateMouseClickUp(point);
            return Success('Mouse up at: ${point.dx.toInt()} ${point.dy.toInt()}');
          }
        }
      }
    }
    return Error(
      AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
      type: ErrorType.noActionAssigned,
    );
  }

  // Release all held keys (useful for cleanup)
  Future<void> releaseAllHeldKeys(List<ControllerButton> list) async {
    for (final action in list) {
      final keyPair = supportedApp?.keymap.getKeyPair(action);
      final longPressKeyPair = supportedApp?.keymap.getKeyPair(action, trigger: ButtonTrigger.longPress);
      if (longPressKeyPair?.physicalKey != null) {
        await keyPressSimulator.simulateKeyUp(longPressKeyPair!.physicalKey);
      } else if (keyPair?.physicalKey != null) {
        await keyPressSimulator.simulateKeyUp(keyPair!.physicalKey);
      }
    }
  }

  @override
  void cleanup() {}
}
