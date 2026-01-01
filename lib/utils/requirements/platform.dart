import 'package:flutter/material.dart';

abstract class PlatformRequirement {
  String name;
  String? description;
  final IconData icon;
  late bool status;

  PlatformRequirement(this.name, {this.description, required this.icon});

  Future<bool> getStatus();

  Future<void> call(BuildContext context, VoidCallback onUpdate);

  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return null;
  }

  Widget? buildDescription() {
    return null;
  }
}
