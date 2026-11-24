import 'package:flutter/material.dart';

abstract class PlatformRequirement {
  String name;
  String? description;
  final IconData icon;
  bool status = false;

  PlatformRequirement(this.name, {this.description, required this.icon});

  /// What the action button says while [status] is false, when "Grant" would
  /// be wrong (e.g. "Open Bluetooth settings"). Null keeps "Grant".
  String? get actionLabel => null;

  /// Shown, but never waited for: nothing the rider does in the app can
  /// satisfy it, and everything else works without it (a PC without a
  /// Bluetooth adapter still finds Wi-Fi trainers and gamepads). Neither the
  /// scan gate nor the permission sheet holds on it.
  bool get isInformational => false;

  Future<bool> getStatus();

  Future<void> call(BuildContext context, VoidCallback onUpdate);

  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return null;
  }

  Widget? buildDescription() {
    return null;
  }
}
