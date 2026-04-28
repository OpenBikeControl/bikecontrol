import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/di2_ble_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/di2_definition.dart';
import 'package:prop/emulators/transporter/bluetooth_transporter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Maps each [InGameAction.dFlyChannelN] to its zero-based channel index in
/// the Di2 indication payload. Kept package-private to avoid leaking the
/// channel numbering scheme outside the emulator.
const Map<InGameAction, int> _channelIndexByAction = {
  InGameAction.dFlyChannel1: 0,
  InGameAction.dFlyChannel2: 1,
  InGameAction.dFlyChannel3: 2,
  InGameAction.dFlyChannel4: 3,
};

/// Virtual Shimano Di2 D-Fly shifter. Wraps a [Di2Definition] (in standalone
/// mode) inside prop's [BluetoothTransporter] so we can advertise the Di2
/// service and emit channel indications without relaying off any upstream
/// BLE device. Currently consumed by the "Wahoo ELEMNT" target — but the
/// shape is generic to any Di2 D-Fly subscriber (e.g. Garmin Edge), which
/// is why the class is named after the protocol rather than the consumer.
class Di2Emulator extends TrainerConnection {
  /// Track which channels are currently held down so we can keep the rest
  /// released on every emitted packet. Index = channel index, value = state.
  final List<Di2ButtonState> _channelStates = List.filled(
    _channelIndexByAction.length,
    Di2ButtonState.released,
  );

  final ValueNotifier<String> _data = ValueNotifier<String>('');
  final Di2Definition _definition;
  BluetoothTransporter? _transporter;

  /// Test seam — when supplied, [_makeTransporter] returns this transporter
  /// instead of a real [BluetoothTransporter]. Production callers must leave
  /// it `null`.
  @visibleForTesting
  BluetoothTransporter Function(Di2Definition def)? transporterFactory;

  Di2Emulator()
    : _definition = Di2Definition.standalone(data: ValueNotifier<String>('')),
      super(
        title: AppLocalizations.current.connectUsingBluetooth,
        type: ConnectionMethodType.bluetooth,
        supportedActions: const [
          InGameAction.dFlyChannel1,
          InGameAction.dFlyChannel2,
          InGameAction.dFlyChannel3,
          InGameAction.dFlyChannel4,
        ],
      );

  @visibleForTesting
  Di2Definition get definition => _definition;

  /// Live data field exposed to UI listeners (mirrors the Di2 definition).
  ValueListenable<String> get data => _data;

  BluetoothTransporter _makeTransporter(Di2Definition def) {
    final factory = transporterFactory;
    if (factory != null) return factory(def);
    return BluetoothTransporter(definition: def, advertisementName: 'BikeControl Di2');
  }

  Future<void> startAdvertising() async {
    if (isStarted.value) return;
    isStarted.value = true;
    final transporter = _makeTransporter(_definition);
    _transporter = transporter;
    transporter.hasSubscribers.addListener(_onSubscribersChanged);
    try {
      await transporter.start();
    } catch (e) {
      transporter.hasSubscribers.removeListener(_onSubscribersChanged);
      _transporter = null;
      isStarted.value = false;
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    final transporter = _transporter;
    if (transporter != null) {
      transporter.hasSubscribers.removeListener(_onSubscribersChanged);
      transporter.dispose();
      _transporter = null;
    }
    isConnected.value = false;
    isStarted.value = false;
  }

  void _onSubscribersChanged() {
    final transporter = _transporter;
    isConnected.value = transporter?.hasSubscribers.value ?? false;
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final action = keyPair.inGameAction;
    final index = _channelIndexByAction[action];
    if (index == null) {
      return NotHandled('Action ${action?.name ?? '<none>'} not supported by Di2Emulator');
    }
    if (_transporter == null) {
      return NotHandled('Di2 emulator is not started');
    }

    if (isKeyDown) {
      _channelStates[index] = keyPair.isLongPress
          ? Di2ButtonState.longPress
          : Di2ButtonState.shortPress;
    }
    if (isKeyUp) {
      _channelStates[index] = Di2ButtonState.released;
    }
    _definition.sendChannelStates(List.of(_channelStates));
    return Success('Sent ${action!.name}');
  }

  @override
  Widget getTile({bool small = false}) => Di2BleTile(small: small);
}
