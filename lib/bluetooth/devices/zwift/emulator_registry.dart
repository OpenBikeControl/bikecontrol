import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon_emulator.dart';

/// Resolves which [DirconEmulator] a companion device (Zwift Click V2 today,
/// future HR strap / second controller, etc.) should attach its
/// [BleDefinition] to.
///
/// When a smart trainer (`ProxyDevice`) is connected, [sharedTrainerEmulator]
/// points at its [DirconEmulator] so companion devices route their
/// definitions through the trainer's transport instead of spinning up a
/// second BLE peripheral / mDNS service. When no trainer is connected,
/// companions fall back to the [standalone] emulator the caller supplies.
class EmulatorRegistry {
  EmulatorRegistry._();

  static final EmulatorRegistry instance = EmulatorRegistry._();

  /// The trainer's emulator, when a `ProxyDevice` is currently connected.
  /// `null` otherwise. Set by `ProxyDevice` on construction; cleared on
  /// disconnect.
  final ValueNotifier<DirconEmulator?> sharedTrainerEmulator =
      ValueNotifier<DirconEmulator?>(null);

  /// Returns the emulator a companion device should attach to. Prefers
  /// [sharedTrainerEmulator]; falls back to [standalone].
  DirconEmulator resolveFor({required DirconEmulator standalone}) =>
      sharedTrainerEmulator.value ?? standalone;
}
