import 'package:flutter/material.dart';

abstract class PlatformRequirement {
  String name;
  String? description;
  late bool status;

  PlatformRequirement(this.name, {this.description});

  Future<void> getStatus();

  Future<void> call(BuildContext context, VoidCallback onUpdate);

  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return null;
  }

  Widget? buildDescription() {
    return null;
  }
}
