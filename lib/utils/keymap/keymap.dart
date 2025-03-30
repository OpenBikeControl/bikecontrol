import 'package:flutter/services.dart';

class Keymap {
  static Keymap myWhoosh = Keymap('MyWhoosh', increase: PhysicalKeyboardKey.keyK, decrease: PhysicalKeyboardKey.keyI);
  static Keymap custom = Keymap('Custom', increase: null, decrease: null);

  static List<Keymap> values = [myWhoosh, custom];

  PhysicalKeyboardKey? increase;
  PhysicalKeyboardKey? decrease;
  final String name;

  Keymap(this.name, {required this.increase, required this.decrease});

  @override
  String toString() {
    if (increase == null && decrease == null) {
      return name;
    }
    return "$name: ${increase?.debugName} + ${decrease?.debugName}";
  }

  List<String> encode() {
    // encode to save in preferences
    return [name, increase?.usbHidUsage.toString() ?? '', decrease?.usbHidUsage.toString() ?? ''];
  }

  static Keymap decode(List<String> data) {
    // decode from preferences
    final name = data[0];
    final keymap = values.firstWhere((element) => element.name == name, orElse: () => custom);

    if (keymap.name != custom.name) {
      return keymap;
    }

    keymap.increase = data[1].isNotEmpty ? PhysicalKeyboardKey(int.parse(data[1])) : null;
    keymap.decrease = data[2].isNotEmpty ? PhysicalKeyboardKey(int.parse(data[2])) : null;
    return keymap;
  }
}
