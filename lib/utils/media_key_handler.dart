import 'dart:io';

import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_key_detector/media_key_detector.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'smtc_stub.dart' if (dart.library.io) 'package:smtc_windows/smtc_windows.dart';

class MediaKeyHandler {
  final ValueNotifier<bool> isMediaKeyDetectionEnabled = ValueNotifier(false);

  bool _smtcInitialized = false;
  double? _lastVolume;
  SMTCWindows? _smtc;

  void initialize() {
    isMediaKeyDetectionEnabled.addListener(() async {
      if (!isMediaKeyDetectionEnabled.value) {
        FlutterVolumeController.removeListener();
        if (Platform.isWindows) {
          _smtc?.disableSmtc();
        } else {
          mediaKeyDetector.setIsPlaying(isPlaying: false);
          mediaKeyDetector.removeListener(_onMediaKeyDetectedListener);
        }
        final hidDevice = core.connection.controllerDevices.firstOrNullWhere(
          (e) => e is HidDevice && e.uniqueId == 'HID Device',
        );
        if (hidDevice != null) {
          core.connection.disconnect(hidDevice, persistForget: false, forget: false);
        }
      } else {
        _ensureHidDevice();
        FlutterVolumeController.addListener(
          (volume) {
            _lastVolume ??= volume;
            if (volume != _lastVolume) {
              final bool hasAction;
              if (volume > _lastVolume!) {
                hasAction = _onMediaKeyDetectedListener(MediaKey.volumeUp);
              } else {
                hasAction = _onMediaKeyDetectedListener(MediaKey.volumeDown);
              }
              if (hasAction) {
                // revert volume
                FlutterVolumeController.setVolume(_lastVolume!);
              } else {
                _lastVolume = volume;
              }
            }
          },
        );
        if (Platform.isWindows) {
          if (!_smtcInitialized) {
            _smtcInitialized = true;
            await SMTCWindows.initialize();
          }

          _smtc = SMTCWindows(
            metadata: const MusicMetadata(
              title: 'BikeControl Media Key Handler',
              album: 'BikeControl',
              albumArtist: 'BikeControl',
              artist: 'BikeControl',
            ),
            // Timeline info for the OS media player
            timeline: const PlaybackTimeline(
              startTimeMs: 0,
              endTimeMs: 1000,
              positionMs: 0,
              minSeekTimeMs: 0,
              maxSeekTimeMs: 1000,
            ),
            config: const SMTCConfig(
              fastForwardEnabled: true,
              nextEnabled: true,
              pauseEnabled: true,
              playEnabled: true,
              rewindEnabled: true,
              prevEnabled: true,
              stopEnabled: true,
            ),
          );
          _smtc!.buttonPressStream.listen(_onMediaKeyPressedListener);
        } else {
          mediaKeyDetector.addListener(_onMediaKeyDetectedListener);
          mediaKeyDetector.setIsPlaying(isPlaying: true);
        }
      }
    });
  }

  HidDevice _ensureHidDevice() {
    // Display label is "Bluetooth Media Remote", but the uniqueId stays
    // "HID Device" so keymaps saved before the rename keep matching.
    final hidDevice = HidDevice('Bluetooth Media Remote', uniqueId: 'HID Device');
    final existing = core.connection.controllerDevices.firstOrNullWhere(
      (e) => e is HidDevice && e.uniqueId == hidDevice.uniqueId,
    );
    if (existing is HidDevice) {
      return existing;
    }
    core.connection.addDevices([hidDevice]);
    return hidDevice;
  }

  bool _onMediaKeyDetectedListener(MediaKey mediaKey) {
    final availableDevice = _ensureHidDevice();

    final keyPressed = mediaKey.name;

    final button = availableDevice.getOrAddButton(
      keyPressed,
      () => ControllerButton(
        keyPressed,
        icon: switch (mediaKey) {
          MediaKey.playPause => LucideIcons.play,
          MediaKey.fastForward => LucideIcons.skipForward,
          MediaKey.rewind => LucideIcons.skipBack,
          MediaKey.volumeUp => Icons.volume_up_outlined,
          MediaKey.volumeDown => Icons.volume_down,
        },
      ),
    );

    // Send press followed by release. HidDevice has supportsLongPress: false,
    // so the action is only executed via the release path
    // (_handleButtonsReleased → _handleSingleButtonTap → performClick).
    availableDevice.handleButtonsClicked([button]);
    availableDevice.handleButtonsClicked([]);

    return core.actionHandler.supportedApp?.keymap.hasAnyMappedAction(button) == true;
  }

  bool _onMediaKeyPressedListener(PressedButton mediaKey) {
    return _onMediaKeyDetectedListener(switch (mediaKey) {
      PressedButton.play => MediaKey.playPause,
      PressedButton.pause => MediaKey.playPause,
      PressedButton.next => MediaKey.fastForward,
      PressedButton.previous => MediaKey.rewind,
      PressedButton.stop => MediaKey.playPause,
      PressedButton.fastForward => MediaKey.fastForward,
      PressedButton.rewind => MediaKey.rewind,
      PressedButton.record => throw UnimplementedError(),
      PressedButton.channelUp => MediaKey.volumeUp,
      PressedButton.channelDown => MediaKey.volumeDown,
    });
  }
}
