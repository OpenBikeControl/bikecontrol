import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/screenshot_folder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/services.dart' show MethodChannel, ModifierKey, PhysicalKeyboardKey;
import 'package:flutter_screen_capture/flutter_screen_capture.dart';
import 'package:image/image.dart' as image_lib;
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:win32/win32.dart' show GetSystemMetrics, SM_CXSCREEN, SM_CYSCREEN;

/// How long a single key click holds the key down before releasing it.
const keyClickHoldDuration = Duration(milliseconds: 50);

/// Presses and releases [key] as one click, holding it for
/// [keyClickHoldDuration] in between. Games that poll key state once per frame
/// miss a press whose down and up arrive back to back.
// ignore: deprecated_member_use
Future<void> simulateKeyClick(PhysicalKeyboardKey? key, List<ModifierKey> modifiers, String? targetApp) async {
  await keyPressSimulator.simulateKeyDown(key, modifiers, targetApp);
  await Future<void>.delayed(keyClickHoldDuration);
  await keyPressSimulator.simulateKeyUp(key, modifiers, targetApp);
}

class DesktopActions extends BaseActions {
  DesktopActions({super.supportedModes = const [SupportedMode.keyboard, SupportedMode.touch, SupportedMode.media]});

  // Track keys that are currently held down in long press mode

  @override
  Future<ActionResult> performMediaKey(PhysicalKeyboardKey key, {required ControllerButton button}) async {
    try {
      await keyPressSimulator.simulateMediaKey(key);
      // Increment command count after successful execution
      await IAPManager.instance.incrementCommandCount();
      return Success('Media key pressed: ${mediaKeyLabel(key)}', button: button);
    } catch (e) {
      return Error('Failed to simulate media key: $e', button: button);
    }
  }

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
    final app = supportedApp;
    if (app == null) {
      return Error(
        AppLocalizations.current.couldNotPerformButtonnamesplitbyuppercaseNoKeymapSet(button.name.splitByUpperCase()),
        type: ErrorType.noKeymapSet,
        button: button,
      );
    }
    final keyPair = app.keymap.getKeyPair(button, trigger: trigger);
    if (keyPair == null) {
      return Error(
        AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
        type: ErrorType.noActionAssigned,
        button: button,
      );
    }

    if (keyPair.screenshotPath?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored(
          'Screenshot capture only runs on key down',
          button: keyPair.buttons.firstOrNull,
        );
      }

      final screenshotDirectory = keyPair.screenshotPath!.trim();
      try {
        final capturedArea = await _captureEntireScreen();
        if (capturedArea == null) {
          return Error(
            'Failed to capture screenshot',
            button: keyPair.buttons.firstOrNull,
          );
        }

        final screenshotFile = await saveScreenshotFile(
          screenshotDirectory,
          image_lib.encodeJpg(
            screenshotImage(
              bytes: capturedArea.buffer,
              width: capturedArea.width,
              height: capturedArea.height,
              platform: defaultTargetPlatform,
            ),
          ),
          DateTime.now(),
        );
        await IAPManager.instance.incrementCommandCount();
        return Success(
          'Screenshot saved: ${screenshotFile.path}',
          button: keyPair.buttons.firstOrNull,
        );
      } catch (e, s) {
        await recordError(e, s, context: 'DesktopActions.screenshot');
        return Error(
          'Failed to save screenshot: $e',
          button: keyPair.buttons.firstOrNull,
        );
      }
    }

    if (keyPair.command?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored(
          'Shortcut launch only runs on key down',
          button: keyPair.buttons.firstOrNull,
        );
      }

      final commandPath = keyPair.command!.trim();
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final launched = await launchUrlString('shortcuts://run-shortcut?name=$commandPath');
        if (!launched) {
          return Error(
            'Failed to launch shortcut: ${keyPair.command}',
            button: keyPair.buttons.firstOrNull,
          );
        }
        await IAPManager.instance.incrementCommandCount();
        return Success(
          'Shortcut launched: ${keyPair.command}',
          button: keyPair.buttons.firstOrNull,
        );
      } else if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
        try {
          final process = await Process.start(commandPath, const [], runInShell: true);
          process.stderr.transform(const Utf8Decoder()).transform(const LineSplitter()).listen((line) {
            core.connection.signalNotification(LogNotification('Command error: $line'));
          });
        } catch (e) {
          return Error(
            'Failed to run command: $e',
            button: keyPair.buttons.firstOrNull,
          );
        }
        await IAPManager.instance.incrementCommandCount();
        return Success(
          'Command launched: $commandPath',
          button: keyPair.buttons.firstOrNull,
        );
      }
    }

    if (core.settings.getLocalEnabled()) {
      // Handle media keys
      if (keyPair.isSpecialKey) {
        return performMediaKey(keyPair.physicalKey!, button: keyPair.buttons.firstOrNull ?? button);
      }

      if (keyPair.physicalKey != null) {
        // Increment command count after successful execution
        await IAPManager.instance.incrementCommandCount();
        final trainerApp = core.settings.getTrainerApp();
        // only those two seem to support targeting specific PIDs, for the rest we just send the key events globally
        final packageName = (trainerApp is Rouvy || trainerApp is MyWhoosh) ? trainerApp!.packageName : null;

        if (isKeyDown && isKeyUp) {
          await simulateKeyClick(keyPair.physicalKey, keyPair.modifiers, packageName);

          return Success(
            'Key clicked: ${keyPair.label}',
            button: keyPair.buttons.firstOrNull,
          );
        } else if (isKeyDown) {
          await keyPressSimulator.simulateKeyDown(
            keyPair.physicalKey,
            keyPair.modifiers,
            core.settings.getTrainerApp()?.name,
          );
          return Success(
            'Key pressed: ${keyPair.label}',
            button: keyPair.buttons.firstOrNull,
          );
        } else {
          await keyPressSimulator.simulateKeyUp(
            keyPair.physicalKey,
            keyPair.modifiers,
            core.settings.getTrainerApp()?.name,
          );
          return Success(
            'Key released: ${keyPair.label}',
            button: keyPair.buttons.firstOrNull,
          );
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
            return Success(
              'Mouse clicked at: ${point.dx.toInt()} ${point.dy.toInt()}',
              button: keyPair.buttons.firstOrNull,
            );
          } else if (isKeyDown) {
            await keyPressSimulator.simulateMouseClickDown(point);
            return Success(
              'Mouse down at: ${point.dx.toInt()} ${point.dy.toInt()}',
              button: keyPair.buttons.firstOrNull,
            );
          } else {
            await keyPressSimulator.simulateMouseClickUp(point);
            return Success(
              'Mouse up at: ${point.dx.toInt()} ${point.dy.toInt()}',
              button: keyPair.buttons.firstOrNull,
            );
          }
        }
      }
    }
    return Error(
      AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
      type: ErrorType.noActionAssigned,
      button: keyPair.buttons.firstOrNull,
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

/// Captures the whole primary display in physical pixels.
///
/// flutter_screen_capture's captureEntireScreen() sizes the capture with
/// screen_retriever's logical size (pixels divided by the display scaling) on
/// Windows, but copies physical pixels, so with scaling above 100 % the right
/// and bottom were cut off (130 % on 5120x1440 saved only 3932x1106). The app
/// is per-monitor DPI aware, so GetSystemMetrics returns the real pixel size;
/// we call the plugin's native method directly because its Dart wrapper would
/// clip the rect back to the logical size.
Future<CapturedScreenArea?> _captureEntireScreen() async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return ScreenCapture().captureEntireScreen();
  }
  final width = GetSystemMetrics(SM_CXSCREEN);
  final height = GetSystemMetrics(SM_CYSCREEN);
  if (width <= 0 || height <= 0) return null;
  final result = await const MethodChannel('flutter_screen_capture').invokeMethod<Map<Object?, Object?>>(
    'captureScreenArea',
    <String, dynamic>{'x': 0, 'y': 0, 'width': width, 'height': height},
  );
  return result == null ? null : CapturedScreenArea.fromJson(result);
}
