import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:window_manager/window_manager.dart' as wm;

class DesktopOverlayController with wm.WindowListener implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  // Snapshot of the main window state to restore on hide.
  Size? _savedSize;
  Offset? _savedPosition;
  bool _savedAlwaysOnTop = false;
  bool _savedSkipTaskbar = false;
  bool _savedResizable = true;

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    if (_showing.value) return const OverlayShowResult.ok();
    try {
      // 1. Capture current window state.
      _savedSize = await wm.windowManager.getSize();
      _savedPosition = await wm.windowManager.getPosition();
      _savedAlwaysOnTop = await wm.windowManager.isAlwaysOnTop();
      _savedSkipTaskbar = await wm.windowManager.isSkipTaskbar();
      _savedResizable = await wm.windowManager.isResizable();

      // 2. Apply compact-overlay window styling.
      await wm.windowManager.setAlwaysOnTop(true);
      await wm.windowManager.setBackgroundColor(const Color(0x00000000));
      await wm.windowManager.setHasShadow(false);
      await wm.windowManager.setResizable(false);
      await wm.windowManager.setSkipTaskbar(true);
      if (Platform.isMacOS) {
        // Stay visible on every Space and over fullscreened apps.
        await wm.windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
      await wm.windowManager.setMinimumSize(const Size(220, 140));
      await wm.windowManager.setSize(const Size(220, 140));

      // Restore last-known overlay position if any.
      final saved = core.settings.getOverlayPosition();
      if (saved != null) {
        await wm.windowManager.setPosition(saved);
      }

      wm.windowManager.addListener(this);

      _showing.value = true;
      trainerOverlayMode.value = true;
      return const OverlayShowResult.ok();
    } catch (e, s) {
      // Best-effort revert.
      await _restore();
      return OverlayShowResult.fail(
        OverlayShowFailure.unknown,
        message: 'Failed to enter overlay mode: $e\n$s',
      );
    }
  }

  @override
  Future<void> hide() async {
    if (!_showing.value) return;
    wm.windowManager.removeListener(this);

    // Persist current overlay position before restoring.
    try {
      final pos = await wm.windowManager.getPosition();
      await core.settings.setOverlayPosition(pos);
    } catch (_) {
      // Position is non-critical.
    }

    await _restore();
    _showing.value = false;
    trainerOverlayMode.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    // Desktop reads fields directly from settings; nothing to push here.
  }

  Future<void> _restore() async {
    try {
      // Restore opaque background before any other property; the transparent
      // overlay color must not leak into the restored main-window state.
      await wm.windowManager.setBackgroundColor(const Color(0xFF000000));
      await wm.windowManager.setAlwaysOnTop(_savedAlwaysOnTop);
      await wm.windowManager.setSkipTaskbar(_savedSkipTaskbar);
      await wm.windowManager.setResizable(_savedResizable);
      if (Platform.isMacOS) {
        await wm.windowManager.setVisibleOnAllWorkspaces(false);
      }
      await wm.windowManager.setMinimumSize(const Size(360, 480));
      if (_savedSize != null) {
        await wm.windowManager.setSize(_savedSize!);
      }
      if (_savedPosition != null) {
        await wm.windowManager.setPosition(_savedPosition!);
      }
      await wm.windowManager.setHasShadow(true);
    } catch (_) {
      // ignore — best-effort
    }
  }

  @override
  void onWindowMoved() {
    // Persist position as the user drags the overlay.
    () async {
      try {
        final pos = await wm.windowManager.getPosition();
        await core.settings.setOverlayPosition(pos);
      } catch (_) {}
    }();
  }
}
