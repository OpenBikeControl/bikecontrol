import 'dart:io';

import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:media_key_detector/media_key_detector.dart';

import 'smtc_stub.dart' if (dart.library.io) 'package:smtc_windows/smtc_windows.dart';

class MediaKeyHandler {
  final ValueNotifier<bool> isMediaKeyDetectionEnabled = ValueNotifier(false);

  bool _smtcInitialized = false;
  SMTCWindows? _smtc;

  void initialize() {
    isMediaKeyDetectionEnabled.addListener(() async {
      if (!isMediaKeyDetectionEnabled.value) {
        if (Platform.isWindows) {
          _smtc?.disableSmtc();
        } else {
          mediaKeyDetector.setIsPlaying(isPlaying: false);
          mediaKeyDetector.removeListener(_onMediaKeyDetectedListener);
        }
      } else {
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

  void _onMediaKeyDetectedListener(MediaKey mediaKey) {
    _onMediaKeyPressedListener(switch (mediaKey) {
      MediaKey.playPause => PressedButton.play,
      MediaKey.rewind => PressedButton.rewind,
      MediaKey.fastForward => PressedButton.fastForward,
      MediaKey.volumeUp => PressedButton.channelUp,
      MediaKey.volumeDown => PressedButton.channelDown,
    });
  }

  Future<void> _onMediaKeyPressedListener(PressedButton mediaKey) async {
    final hidDevice = HidDevice('HID Device');
    final keyPressed = mediaKey.name;

    final button = hidDevice.getOrAddButton(
      keyPressed,
      () => ControllerButton(keyPressed),
    );

    var availableDevice = core.connection.controllerDevices.firstOrNullWhere(
      (e) => e.toString() == hidDevice.toString(),
    );
    if (availableDevice == null) {
      core.connection.addDevices([hidDevice]);
      availableDevice = hidDevice;
    }
    availableDevice.handleButtonsClickedWithoutLongPressSupport([button]);
  }
}
