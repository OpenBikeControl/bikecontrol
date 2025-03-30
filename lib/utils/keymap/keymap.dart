import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';

class Keymap {
  static Keymap myWhoosh = Keymap(
    'MyWhoosh',
    increase: KeyPair(physicalKey: PhysicalKeyboardKey.keyK, logicalKey: LogicalKeyboardKey.keyK),
    decrease: KeyPair(physicalKey: PhysicalKeyboardKey.keyI, logicalKey: LogicalKeyboardKey.keyI),
  );
  static Keymap custom = Keymap('Custom', increase: null, decrease: null);

  static List<Keymap> values = [myWhoosh, custom];

  KeyPair? increase;
  KeyPair? decrease;
  final String name;

  Keymap(this.name, {required this.increase, required this.decrease});

  @override
  String toString() {
    if (increase == null && decrease == null) {
      return name;
    }
    return "$name: ${increase?.logicalKey.keyLabel} + ${decrease?.logicalKey.keyLabel}";
  }

  List<String> encode() {
    // encode to save in preferences
    return [
      name,
      increase?.logicalKey.keyId.toString() ?? '',
      increase?.physicalKey.usbHidUsage.toString() ?? '',
      decrease?.logicalKey.keyId.toString() ?? '',
      decrease?.physicalKey.usbHidUsage.toString() ?? '',
    ];
  }

  static Keymap? decode(List<String> data) {
    // decode from preferences

    if (data.length < 4) {
      return null;
    }
    final name = data[0];
    final keymap = values.firstOrNullWhere((element) => element.name == name);

    if (keymap == null) {
      return null;
    }

    if (keymap.name != custom.name) {
      return keymap;
    }

    if (data.sublist(1).all((e) => e.isNotEmpty)) {
      keymap.increase = KeyPair(
        physicalKey: PhysicalKeyboardKey(int.parse(data[2])),
        logicalKey: LogicalKeyboardKey(int.parse(data[1])),
      );
      keymap.decrease = KeyPair(
        physicalKey: PhysicalKeyboardKey(int.parse(data[4])),
        logicalKey: LogicalKeyboardKey(int.parse(data[3])),
      );
      return keymap;
    } else {
      return null;
    }
  }
}

class KeyPair {
  final PhysicalKeyboardKey physicalKey;
  final LogicalKeyboardKey logicalKey;

  KeyPair({required this.physicalKey, required this.logicalKey});
}
