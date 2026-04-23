import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

void main() {
  group('DirconEmulator advertisementNameOverride', () {
    test('override takes precedence over any derived name', () {
      final emulator = DirconEmulator();
      emulator.advertisementNameOverride = () => 'BikeControl - 20 min trial';
      expect(emulator.advertisementNameOverride!.call(), 'BikeControl - 20 min trial');
    });

    test('override is null by default', () {
      final emulator = DirconEmulator();
      expect(emulator.advertisementNameOverride, isNull);
    });
  });
}
