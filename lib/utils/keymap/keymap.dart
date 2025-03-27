import 'package:flutter/services.dart';

enum Keymap {
  myWhoosh(increase: PhysicalKeyboardKey.keyK, decrease: PhysicalKeyboardKey.keyI),
  indieVelo(increase: PhysicalKeyboardKey(0x70030), decrease: PhysicalKeyboardKey(0x70038)),
  plusMinus(increase: PhysicalKeyboardKey(0x70030), decrease: PhysicalKeyboardKey(0x70038));

  final PhysicalKeyboardKey increase;
  final PhysicalKeyboardKey decrease;

  const Keymap({required this.increase, required this.decrease});
}
