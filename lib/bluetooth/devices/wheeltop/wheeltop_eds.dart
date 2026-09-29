import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/wheeltop/wheeltop_probe.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/wheeltop_probe_toggle.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

/// Variant of a WHEELTOP EDS shifter, taken from the type byte in its
/// advertisement. All variants speak the identical button protocol.
enum WheeltopEdsType {
  ox('OX', 0x37),
  txFront('TX Front', 0x39),
  txLeft('TX Left', 0x36),
  txRight('TX Right', 0x38);

  const WheeltopEdsType(this.label, this.typeByte);

  final String label;

  /// The device-type byte as advertised — TX firmware also embeds it as the
  /// sender byte in its 4-byte frames.
  final int typeByte;

  static WheeltopEdsType? fromTypeByte(int byte) => switch (byte) {
    0x37 => WheeltopEdsType.ox,
    0x39 => WheeltopEdsType.txFront,
    0x36 => WheeltopEdsType.txLeft,
    0x38 => WheeltopEdsType.txRight,
    _ => null,
  };
}

/// WHEELTOP EDS wireless shifter (OX / TX family).
///
/// The shifter is a BLE peripheral exposing a Nordic-UART-style service. It
/// has two physical buttons (top / bottom) and a slide switch: position "R"
/// sends the normal shift opcodes, position "T" sends distinct fine-tune
/// opcodes — surfaced here as two extra assignable buttons. The shifter has
/// no gear awareness; it only reports button state.
class WheeltopEds extends BluetoothDevice {
  WheeltopEds(
    super.scanResult, {
    required this.edsType,
    this.batteryCentivolts,
    String? advertisedFirmware,
  }) : super(
         availableButtons: WheeltopEdsButtons.values,
         allowMultiple: true,
         isBeta: true,
       ) {
    firmwareVersion = advertisedFirmware;
  }

  final WheeltopEdsType edsType;

  /// Battery voltage from the advertisement, in volts * 100 (e.g. 292 = 2.92 V).
  final int? batteryCentivolts;

  /// The shifter advertises no usable BLE name.
  @override
  String get name => 'WHEELTOP EDS ${edsType.label}';

  /// The pod accepts a central only while its rear derailleur is not claiming
  /// it — auto-connect gives up quickly and explains instead of spamming.
  @override
  int get maxAutoConnectAttempts => 3;

  @override
  String? get connectionGuidance => AppLocalizations.current.wheeltopClaimedByDerailleurHint;

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    return [
      if (batteryCentivolts != null)
        Text(AppLocalizations.current.wheeltopShifterBattery((batteryCentivolts! / 100).toStringAsFixed(2))).xSmall,
      Text(AppLocalizations.current.wheeltopClaimedByDerailleurHint).xSmall,
      Text(AppLocalizations.current.wheeltopSlideSwitchHint).xSmall,
    ];
  }

  /// Returns a [WheeltopEds] when [scanResult] carries the EDS shifter
  /// advertisement, else null.
  ///
  /// The advertisement is a fixed 7-byte prefix followed by a type byte,
  /// firmware version, and battery voltage. Depending on the platform, the
  /// first two bytes may have been split off as a little-endian company id or
  /// left in the payload — both shapes are matched.
  static WheeltopEds? tryFrom(BleDevice scanResult) {
    for (final manufacturerData in scanResult.manufacturerDataList) {
      final adv = _matchedAdvBytes(manufacturerData);
      if (adv == null) continue;

      final type = WheeltopEdsType.fromTypeByte(adv[WheeltopEdsConstants.ADV_TYPE_INDEX]);
      if (type == null) continue;

      String? firmware;
      int? centivolts;
      if (adv.length > WheeltopEdsConstants.ADV_BATTERY_INDEX + 1) {
        firmware =
            '${adv[WheeltopEdsConstants.ADV_FIRMWARE_INDEX]}.${adv[WheeltopEdsConstants.ADV_FIRMWARE_INDEX + 1]}';
        centivolts =
            (adv[WheeltopEdsConstants.ADV_BATTERY_INDEX] << 8) | adv[WheeltopEdsConstants.ADV_BATTERY_INDEX + 1];
      }
      return WheeltopEds(
        scanResult,
        edsType: type,
        advertisedFirmware: firmware,
        batteryCentivolts: centivolts,
      );
    }
    return null;
  }

  /// The full advertisement bytes (prefix included) when [manufacturerData]
  /// matches, else null.
  static Uint8List? _matchedAdvBytes(ManufacturerData manufacturerData) {
    final reconstructed = Uint8List.fromList([
      manufacturerData.companyId & 0xff,
      (manufacturerData.companyId >> 8) & 0xff,
      ...manufacturerData.payload,
    ]);
    if (_startsWithAdvPrefix(reconstructed)) return reconstructed;
    if (_startsWithAdvPrefix(manufacturerData.payload)) return manufacturerData.payload;
    return null;
  }

  static bool _startsWithAdvPrefix(Uint8List bytes) {
    final prefix = WheeltopEdsConstants.ADV_PREFIX;
    // Must at least contain the prefix and the type byte.
    if (bytes.length <= prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  final Set<ControllerButton> _pressedButtons = {};
  final Set<String> _subscribedCharacteristics = {};

  /// Hex dumps of invalid frames and opcodes already logged on this
  /// connection. TX firmware repeats its status frame at 1 Hz — without the
  /// dedupe a single unknown frame floods the support log.
  final Set<String> _loggedInvalidPackets = {};
  final Set<int> _loggedUnhandledOpcodes = {};

  /// Keepalive-reply experiment for the current connection. Armed lazily on
  /// the first `0x10` status frame (see [_armProbeIfNeeded]) rather than at
  /// connect: the frame is what proves this pod needs a reply, and it is the
  /// only moment we can reach — the pod drops so fast the user can never open
  /// its detail page to toggle anything.
  WheeltopProbe? _probe;

  /// The NUS service uuid and its writable characteristics, captured in
  /// [handleServices] so the probe can be built later, when a status frame
  /// arrives.
  String? _probeServiceUuid;
  List<ProbeTarget>? _probeWritableCharacteristics;

  /// While the keepalive experiment is enabled the reconnect loop must keep
  /// cycling even though the pod drops within seconds — each cycle lets the
  /// probe try the next candidate. So this device opts out of the quick-drop
  /// backoff [Connection] would otherwise apply.
  @override
  bool get keepsReconnectingWhileDropping => core.settings.getWheeltopProbeEnabled();

  /// Clears the per-connection button/subscription state. Extracted from
  /// [disconnect] so it can be exercised directly in tests that cannot reach
  /// the real BLE platform channels that [disconnect] otherwise hits via
  /// `super.disconnect()`.
  @visibleForTesting
  void resetConnectionState() {
    _pressedButtons.clear();
    _subscribedCharacteristics.clear();
    _loggedInvalidPackets.clear();
    _loggedUnhandledOpcodes.clear();
    _probe?.end();
    _probe = null;
    _probeServiceUuid = null;
    _probeWritableCharacteristics = null;
  }

  @override
  Future<void> disconnect() async {
    // Without this, a mid-hold BLE drop that never delivers a release packet
    // leaves the button "pressed" (and its characteristic "subscribed") on
    // this instance; a reconnect would then silently swallow the next press
    // via Set.add returning false.
    resetConnectionState();
    await super.disconnect();
  }

  /// The keepalive-experiment switch lives in the detail page's
  /// "Preferences" section so it shows only when the entry is opened, not on
  /// the compact overview card (ZwiftClickV2 pattern).
  @override
  Widget? buildPreferences(BuildContext context) {
    final superPreferences = super.buildPreferences(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (superPreferences != null) superPreferences,
        const WheeltopProbeToggle(),
      ],
    );
  }

  /// Button events are notified on 6e400002, but the pod's keepalive reply may
  /// land on a different slot (6e400003 is the stock Nordic UART slot the RD
  /// would receive on). Subscribe to EVERY notify/indicate-capable
  /// characteristic so a reply is captured whichever slot it uses — the strict
  /// packet validation makes stray notifications harmless, and the pressed-set
  /// dedup absorbs a button event that a second slot happens to duplicate.
  /// 6e400002 is listed first for log readability. If the service advertises no
  /// notify/indicate characteristic at all, still attempt 6e400002 so we at
  /// least log a subscribe failure instead of silently doing nothing.
  ///
  /// Extracted from [handleServices] so the selection logic can be tested
  /// directly, without reaching the real BLE platform channel.
  @visibleForTesting
  static List<String> selectSubscriptionTargets(List<BleCharacteristic> characteristics) {
    final txUuid = WheeltopEdsConstants.TX_CHARACTERISTIC_UUID.toLowerCase();
    final notifiable = characteristics
        .where(
          (c) =>
              c.properties.contains(CharacteristicProperty.notify) ||
              c.properties.contains(CharacteristicProperty.indicate),
        )
        .map((c) => c.uuid)
        .toList();

    if (notifiable.isEmpty) return [WheeltopEdsConstants.TX_CHARACTERISTIC_UUID];
    return [
      ...notifiable.where((u) => u.toLowerCase() == txUuid),
      ...notifiable.where((u) => u.toLowerCase() != txUuid),
    ];
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == WheeltopEdsConstants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${WheeltopEdsConstants.SERVICE_UUID}'),
    );

    for (final uuid in selectSubscriptionTargets(service.characteristics)) {
      try {
        await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, uuid);
        _subscribedCharacteristics.add(uuid.toLowerCase());
      } catch (e, st) {
        actionStreamInternal.add(LogNotification('WHEELTOP EDS: could not subscribe to $uuid: $e\n$st'));
      }
    }

    // Stash the writable characteristics for the keepalive probe, which is
    // armed later, only if this pod turns out to send status frames.
    _probeServiceUuid = service.uuid;
    _probeWritableCharacteristics = service.characteristics
        .where(
          (c) =>
              c.properties.contains(CharacteristicProperty.write) ||
              c.properties.contains(CharacteristicProperty.writeWithoutResponse),
        )
        .map(
          (c) => (
            uuid: c.uuid,
            withoutResponse: c.properties.contains(CharacteristicProperty.writeWithoutResponse),
          ),
        )
        .toList();
  }

  /// Arms the keepalive probe on the first status frame, if the experiment is
  /// enabled and this pod exposes a writable characteristic. Answers that
  /// first frame with the candidate; returns false when no probe is running.
  bool _armProbeIfNeeded() {
    if (_probe != null) return true;
    // Check what we can probe with before consulting the setting — nothing to
    // write to means no probe regardless (and keeps direct-processCharacteristic
    // unit tests from needing initialized settings).
    final serviceUuid = _probeServiceUuid;
    final writable = _probeWritableCharacteristics;
    if (serviceUuid == null || writable == null || writable.isEmpty) return false;
    if (!core.settings.getWheeltopProbeEnabled()) return false;

    _probe = WheeltopProbe(
      deviceId: device.deviceId,
      typeByte: edsType.typeByte,
      writableCharacteristics: writable,
      write: (uuid, value, {required withoutResponse}) => UniversalBle.write(
        device.deviceId,
        serviceUuid,
        uuid,
        value,
        withoutResponse: withoutResponse,
      ),
      log: (message) => actionStreamInternal.add(LogNotification(message)),
    );
    // start() logs the candidate and writes it once — that write answers the
    // status frame that just arrived.
    _probe!.start();
    return true;
  }

  /// The button opcode when [bytes] is a valid frame, else null. Two frame
  /// shapes exist in the field:
  /// - 3 bytes `04 code xor` with `xor == 0x04 ^ code` (OX firmware);
  /// - 4 bytes `04 type code sum` (TX firmware): `type` is the unit's
  ///   advertisement type byte and `sum == (0x04 + type + code) & 0xff`.
  ///   Both checksums agree for every button code without bit 2 set, which is
  ///   why the 3-byte XOR shape alone looked sufficient before TX hardware
  ///   reports.
  static int? _validatedOpcode(Uint8List bytes) {
    if (bytes.length == 3 && bytes[0] == WheeltopEdsConstants.PACKET_PREFIX && bytes[2] == (bytes[0] ^ bytes[1])) {
      return bytes[1];
    }
    if (bytes.length == 4 &&
        bytes[0] == WheeltopEdsConstants.PACKET_PREFIX &&
        WheeltopEdsType.fromTypeByte(bytes[1]) != null &&
        bytes[3] == ((bytes[0] + bytes[1] + bytes[2]) & 0xff)) {
      return bytes[2];
    }
    return null;
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    final uuid = characteristic.toLowerCase();
    // While probing, log every inbound frame verbatim (all slots) so the
    // support log is a full transcript of the pod's traffic.
    _probe?.logIncoming(uuid, bytes);
    if (uuid != WheeltopEdsConstants.TX_CHARACTERISTIC_UUID.toLowerCase() &&
        !_subscribedCharacteristics.contains(uuid)) {
      return;
    }

    final opcode = _validatedOpcode(bytes);
    if (opcode == null) {
      final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      if (_loggedInvalidPackets.add('$uuid:$hex')) {
        actionStreamInternal.add(
          LogNotification(
            'WHEELTOP EDS: invalid packet: ${hex.isEmpty ? '(empty)' : hex} '
            '(len ${bytes.length}, on ${uuid.length >= 8 ? uuid.substring(0, 8) : uuid}, logged once per connection)',
          ),
        );
      }
      return;
    }

    switch (opcode) {
      case WheeltopEdsConstants.OPCODE_BOTTOM_PRESSED:
        await _press(availableButtons[WheeltopEdsButtons.indexShiftDown]);
      case WheeltopEdsConstants.OPCODE_TOP_PRESSED:
        await _press(availableButtons[WheeltopEdsButtons.indexShiftUp]);
      case WheeltopEdsConstants.OPCODE_BOTTOM_PRESSED_FINE_TUNE:
        await _press(availableButtons[WheeltopEdsButtons.indexFineTuneDown]);
      case WheeltopEdsConstants.OPCODE_TOP_PRESSED_FINE_TUNE:
        await _press(availableButtons[WheeltopEdsButtons.indexFineTuneUp]);
      case WheeltopEdsConstants.OPCODE_BOTTOM_HELD:
      case WheeltopEdsConstants.OPCODE_TOP_HELD:
      case WheeltopEdsConstants.OPCODE_BOTTOM_HELD_FINE_TUNE:
      case WheeltopEdsConstants.OPCODE_TOP_HELD_FINE_TUNE:
        // The shifter repeats these every ~500 ms while a button is held.
        // BaseDevice's long-press machinery already derives hold behavior
        // from the press/release events, so the device repeats are dropped.
        break;
      case WheeltopEdsConstants.OPCODE_BOTTOM_RELEASED:
        await _release([
          availableButtons[WheeltopEdsButtons.indexShiftDown],
          availableButtons[WheeltopEdsButtons.indexFineTuneDown],
        ]);
      case WheeltopEdsConstants.OPCODE_TOP_RELEASED:
        await _release([
          availableButtons[WheeltopEdsButtons.indexShiftUp],
          availableButtons[WheeltopEdsButtons.indexFineTuneUp],
        ]);
      case WheeltopEdsConstants.OPCODE_TX_STATUS:
        // TX firmware sends this status/hello frame at 1 Hz starting ~300 ms
        // after connect. The reply the derailleur gives is unknown —
        // unanswered, the pod drops the link after three frames. Arm the
        // probe on the first frame (its start() writes the answer to it), and
        // answer every frame after that with onStatusFrame().
        {
          final wasArmed = _probe != null;
          if (_armProbeIfNeeded() && wasArmed) {
            await _probe!.onStatusFrame();
          }
        }
        if (_loggedUnhandledOpcodes.add(opcode)) {
          actionStreamInternal.add(
            LogNotification('WHEELTOP EDS: status frame 0x10 (pod may disconnect while its reply is unknown)'),
          );
        }
      default:
        // A valid frame with an unknown opcode is exactly what a probe
        // response would look like — the raw transcript (logIncoming) already
        // captured its bytes; note the opcode once.
        if (_loggedUnhandledOpcodes.add(opcode)) {
          actionStreamInternal.add(
            LogNotification(
              'WHEELTOP EDS: unknown opcode 0x${opcode.toRadixString(16).padLeft(2, '0')} (logged once per connection)',
            ),
          );
        }
    }
  }

  Future<void> _press(ControllerButton button) async {
    if (_pressedButtons.add(button)) {
      await handleButtonsClicked(_pressedButtons.toList());
    }
  }

  /// A release opcode is shared between R- and T-mode, so both logical
  /// buttons of the physical button are cleared.
  Future<void> _release(List<ControllerButton> buttons) async {
    var changed = false;
    for (final button in buttons) {
      changed = _pressedButtons.remove(button) || changed;
    }
    if (changed) {
      await handleButtonsClicked(_pressedButtons.toList());
    }
  }
}

class WheeltopEdsConstants {
  // Nordic UART Service.
  static const String SERVICE_UUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  // Button events are notified here.
  static const String TX_CHARACTERISTIC_UUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// Constant first 7 bytes of the manufacturer-data advertisement.
  static const List<int> ADV_PREFIX = [0x07, 0x0f, 0x00, 0x14, 0x55, 0x6a, 0x84];

  // Offsets into the full advertisement bytes (prefix included).
  static const int ADV_TYPE_INDEX = 7;
  static const int ADV_FIRMWARE_INDEX = 8; // 2 bytes: major, minor
  static const int ADV_BATTERY_INDEX = 10; // 2 bytes big-endian: volts * 100

  static const int PACKET_PREFIX = 0x04;

  static const int OPCODE_BOTTOM_PRESSED = 0x01;
  static const int OPCODE_TOP_PRESSED = 0x02;
  static const int OPCODE_BOTTOM_HELD = 0x03;
  static const int OPCODE_TOP_HELD = 0x04;
  static const int OPCODE_BOTTOM_PRESSED_FINE_TUNE = 0x05;
  static const int OPCODE_TOP_PRESSED_FINE_TUNE = 0x06;
  static const int OPCODE_BOTTOM_HELD_FINE_TUNE = 0x07;
  static const int OPCODE_TOP_HELD_FINE_TUNE = 0x08;
  static const int OPCODE_BOTTOM_RELEASED = 0x09;
  static const int OPCODE_TOP_RELEASED = 0x0a;

  /// 1 Hz status/hello frame from TX firmware (`04 type 10 sum`). Meaning
  /// and expected reply are unverified; the pod disconnects after three
  /// unanswered frames.
  static const int OPCODE_TX_STATUS = 0x10;
}

class WheeltopEdsButtons {
  static const ControllerButton shiftUp = ControllerButton(
    'edsShiftUp',
    action: InGameAction.shiftUp,
    icon: LucideIcons.chevronUp,
  );

  static const ControllerButton shiftDown = ControllerButton(
    'edsShiftDown',
    action: InGameAction.shiftDown,
    icon: LucideIcons.chevronDown,
  );

  /// Sent when the slide switch is in the "T" (fine-tune) position — two
  /// spare buttons with no default action.
  static const ControllerButton fineTuneUp = ControllerButton(
    'edsFineTuneUp',
    icon: LucideIcons.chevronsUp,
  );

  static const ControllerButton fineTuneDown = ControllerButton(
    'edsFineTuneDown',
    icon: LucideIcons.chevronsDown,
  );

  static const List<ControllerButton> values = [shiftUp, shiftDown, fineTuneUp, fineTuneDown];

  static const int indexShiftUp = 0;
  static const int indexShiftDown = 1;
  static const int indexFineTuneUp = 2;
  static const int indexFineTuneDown = 3;
}
