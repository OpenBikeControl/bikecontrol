import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show SramDeviceInfo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

SramAxs _device() => SramAxs(BleDevice(deviceId: 'dev1', name: 'SRAM 42'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Constructing a BluetoothDevice touches `core.actionHandler` (BaseDevice's
  // constructor checks `supportedApp`), so it must be initialized before any
  // test builds a SramAxs, even though `logicalButtonName` itself is pure.
  // `logicalButtonName` never touches `core.settings`, so unlike other device
  // tests (e.g. test/shimano_di2_test.dart) we don't need `core.settings.init()`.
  core.actionHandler = StubActions();

  test('names a decoded paddle press by shifter, in first-seen order', () {
    final d = _device();
    // First unique serial → "Shifter A"; paddle mask (1) → "Paddle".
    expect(d.logicalButtonName(100, 1), 'SRAM Shifter A – Paddle');
    // Second serial → "Shifter B".
    expect(d.logicalButtonName(200, 1), 'SRAM Shifter B – Paddle');
  });

  test('degraded press (mask null) names by serial only', () {
    final d = _device();
    expect(d.logicalButtonName(100, null), 'SRAM Shifter A');
  });

  test('button decoded before the serial arrives gets a shifter-less label (no double space)', () {
    final d = _device();
    final name = d.logicalButtonName(null, 1);
    expect(name, 'SRAM Paddle');
    expect(name.contains('  '), isFalse);
  });

  test('a decoded device_type (field 2) names left/right with no serial or advert', () {
    final d = _device();
    // Both paddles report mask 1; only the device_type tells them apart. Without
    // it they'd both be "SRAM Paddle" — the tester's "both shifters do the same".
    expect(d.logicalButtonName(null, 1, deviceType: 0), 'SRAM Left Shifter');
    expect(d.logicalButtonName(null, 1, deviceType: 1), 'SRAM Right Shifter');
    // The left/right names are distinct → distinct keymap entries.
    expect(d.logicalButtonName(null, 1, deviceType: 0), isNot(d.logicalButtonName(null, 1, deviceType: 1)));
    // A decoded side also labels the aux button per §6.4.
    expect(d.logicalButtonName(null, 2, deviceType: 0), 'SRAM Left – Aux Top');
  });

  test('two wireless blips (WB_2=97, WB_3=98) get distinct names → separate keymap entries', () {
    final d = _device();
    // Real capture (support 650f1851): a rider's left/right Blips decoded as
    // WB_2 (device_type 97) and WB_3 (98), both mask 1. They both named to
    // "SRAM Wireless Blip" and so shared one control; each is now its own button
    // so one can be shift-up and the other shift-down.
    expect(d.logicalButtonName(null, 1, deviceType: 97), 'SRAM Wireless Blip 2');
    expect(d.logicalButtonName(null, 1, deviceType: 98), 'SRAM Wireless Blip 3');
    expect(
      d.logicalButtonName(null, 1, deviceType: 97),
      isNot(d.logicalButtonName(null, 1, deviceType: 98)),
    );
  });

  test('a stored device_type re-registers under the same name as the live press', () {
    final d = _device();
    // Live press named it "SRAM Left Shifter"; the persisted record (serial -1,
    // mask 1, device_type 0) must reproduce that exact name — no duplicate entry.
    expect(d.storedButtonName(-1, 1, storedDeviceType: 0), d.logicalButtonName(null, 1, deviceType: 0));
    expect(d.storedButtonName(-1, 1, storedDeviceType: 1), 'SRAM Right Shifter');
  });

  test('the two paddles default to opposite actions so a lever can shift down', () {
    final d = _device();
    // Left paddle → shift DOWN; right paddle → shift UP. This is the fix for
    // "shifting can only increase gears" — the shifters are no longer identical.
    expect(d.defaultAction(0, 1), InGameAction.shiftDown); // left paddle
    expect(d.defaultAction(1, 1), InGameAction.shiftUp); // right paddle
    // Non-paddle buttons and unknown-side presses stay on the safe shift-up default.
    expect(d.defaultAction(0, 2), InGameAction.shiftUp); // left aux
    expect(d.defaultAction(null, 1), InGameAction.shiftUp); // side unknown
  });

  test('fully anonymous press falls back to the legacy label', () {
    final d = _device();
    expect(d.logicalButtonName(null, null), 'SRAM Button');
  });

  test('stored -1 sentinels re-register as the degraded label, not Button 0x-1', () {
    final d = _device();
    expect(d.storedButtonName(100, -1), 'SRAM Shifter A');
    expect(d.storedButtonName(-1, -1), 'SRAM Button');
  });

  test('§6.4: names buttons from an advertised shifter type/model, degrades without one', () {
    final d = _device();
    final leftLever = SramDeviceInfo(serial: 100, model: 1007, deviceType: 0);
    final rightLever = SramDeviceInfo(serial: 200, model: 1007, deviceType: 1);
    expect(d.buttonNameFor(leftLever, 100, 1), 'SRAM Left Shifter');
    expect(d.buttonNameFor(leftLever, 100, 2), 'SRAM Left – Aux Top');
    expect(d.buttonNameFor(rightLever, 200, 1), 'SRAM Right Shifter');
    expect(d.buttonNameFor(null, 100, 1), 'SRAM Shifter A – Paddle'); // no advert → fallback
  });

  test('§6.4 naming is stable across sessions via a persisted shifter advert', () async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    // A left drop-bar lever (type 0, model 1007) seen in a PRIOR session, with
    // no live advert this session — naming must still resolve from persistence.
    core.settings.setSramShifter('dev1', 500, 0, 1007);

    final d = _device(); // deviceId 'dev1' → matches the persisted scope
    expect(d.logicalButtonName(500, 1), 'SRAM Left Shifter');
    expect(d.logicalButtonName(500, 2), 'SRAM Left – Aux Top');
    // An un-persisted serial still degrades to the legacy label.
    expect(d.logicalButtonName(600, 1), 'SRAM Shifter A – Paddle');
  });

  test('the press side wins over a stored side for a stale serial', () async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    // The serial on a press is the last one seen, not necessarily the pressing
    // shifter's: a right-lever press can arrive with the left lever's serial.
    core.settings.setSramShifter('dev1', 500, 0, 1007);

    final d = _device();
    expect(d.logicalButtonName(500, 1, deviceType: 1), 'SRAM Right Shifter');
    expect(d.logicalButtonName(500, 2, deviceType: 1), 'SRAM Right – Aux Top');
    // A matching side keeps resolving from the stored info.
    expect(d.logicalButtonName(500, 1, deviceType: 0), 'SRAM Left Shifter');
  });
}
