import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'shimano_ble_transport.dart';
import 'shimano_setup_sheet.dart';

class ShimanoDi2 extends BluetoothDevice {
  ShimanoDi2(super.scanResult) : super(availableButtons: [], buttonPrefix: 'D-Fly Channel ');

  /// Config seam (18FF E-TUBE service), present on wireless units such as the
  /// RD-R7150. Null when the unit only exposes the 18EF runtime D-FLY service.
  ShimanoBleTransport? _configTransport;

  String get _serialKey => device.deviceId;

  bool get hasConfigService => _configTransport != null;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ShimanoDi2Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ShimanoDi2Constants.D_FLY_CHANNEL_UUID}'),
    );

    await UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);

    // The 18FF E-TUBE config service (SERVICE_UUID_ALTERNATIVE) unlocks the
    // guided D-FLY auto-assign/restore flow. Its GATT dance runs through
    // [ShimanoConfig] over this transport; notifications are routed back from
    // [processCharacteristic].
    final hasConfig = services.any(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase(),
    );
    _configTransport = hasConfig ? ShimanoBleTransport(device.deviceId, services) : null;
  }

  final _lastButtons = <int, ({int value, _Di2State type})>{};
  bool _isInitialized = false;

  @override
  String get buttonExplanation => 'Click a D-Fly button to configure them.';

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    Logger.info('Received data from $characteristic: ${bytesToReadableHex(bytes)}');

    // Route E-TUBE config notifications/indications (PCE response 2AF9, auth
    // control 2AF3) to the config transport's inbox.
    final lower = characteristic.toLowerCase();
    if (_configTransport != null &&
        (lower == ShimanoDi2Config.pceResponseChar || lower == ShimanoDi2Config.authControlChar)) {
      _configTransport!.onNotification(lower, bytes);
      return;
    }

    if (characteristic.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID) {
      final channels = bytes.sublist(1);

      // On first data reception, just initialize the state without triggering buttons
      if (!_isInitialized) {
        channels.forEachIndexed((int value, int index) {
          final readableIndex = index + 1;
          _lastButtons[index] = (value: value, type: _Di2State.released);

          getOrAddButton(
            'D-Fly Channel $readableIndex',
            () => ControllerButton('D-Fly Channel $readableIndex', sourceDeviceId: device.deviceId),
          );
        });
        _isInitialized = true;
        return Future.value();
      }

      var actualChange = false;
      channels.forEachIndexed((int value, int index) {
        final didChange = _lastButtons[index]?.value != value;

        final readableIndex = index + 1;

        if (didChange) {
          if ((value & 0x10) != 0) {
            if (_lastButtons[index]?.type == _Di2State.longPress || _lastButtons[index]?.type == _Di2State.keep) {
              // short press is triggered after long press, until it's released later on
              _lastButtons[index] = (value: value, type: _Di2State.keep);
              Logger.info('Button $readableIndex still long pressed');
            } else {
              _lastButtons[index] = (value: value, type: _Di2State.shortPress);
              actualChange = true;
              Logger.info('Button $readableIndex short pressed');
            }
          } else if ((value & 0x20) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.longPress);
            actualChange = true;
            Logger.info('Button $readableIndex long pressed');
          } else if ((value & 0x40) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.doublePress);
            actualChange = true;
            Logger.info('Button $readableIndex double pressed');
          } else {
            _lastButtons[index] = (value: value, type: _Di2State.released);
            actualChange = true;
            Logger.info('Button $readableIndex released');
          }
        }
      });

      if (actualChange) {
        final Map<_Di2State, List<ControllerButton>> mapped = _lastButtons.entries.groupBy((e) => e.value.type).map((
          key,
          value,
        ) {
          final buttons = value
              .map((entry) => availableButtons.firstWhere((button) => button.name == 'D-Fly Channel ${entry.key + 1}'))
              .toList();
          return MapEntry(key, buttons);
        });

        final shortPress = [...?mapped[_Di2State.shortPress], ...?mapped[_Di2State.doublePress]];
        if (shortPress.isNotEmpty) {
          Logger.debug('Short Press Buttons to trigger: ${shortPress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(shortPress);
          handleButtonsClicked([]);
          _resetButtonsForState([_Di2State.shortPress]);
        }

        final longPress = mapped[_Di2State.longPress] ?? [];
        if (longPress.isNotEmpty) {
          Logger.debug('Long Press Buttons to trigger: ${longPress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(longPress);
        }

        final released = mapped[_Di2State.released] ?? [];
        final keepPress = mapped[_Di2State.longPress] ?? [];

        if (released.isNotEmpty && keepPress.isEmpty) {
          Logger.debug('Releasing all Buttons');
          handleButtonsClicked([]);
        }

        final doublePress = mapped[_Di2State.doublePress] ?? [];
        if (doublePress.isNotEmpty) {
          Logger.debug('Buttons to still trigger: ${doublePress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(doublePress);
          handleButtonsClicked([]);
          _resetButtonsForState([_Di2State.doublePress]);
        }
      }
    }
  }

  void _resetButtonsForState(List<_Di2State> list) {
    _lastButtons.forEach((key, value) {
      if (list.contains(value.type)) {
        _lastButtons[key] = (value: value.value, type: _Di2State.released);
      }
    });
  }

  // ── Guided D-FLY auto-assign / restore (18FF config service) ──────────────

  /// Whether D-FLY has been auto-assigned (so the buttons report over the
  /// radio) and the original config is still backed up to put back.
  bool get isDflyAssigned => core.settings.getShimanoDflyAssigned(_serialKey);

  /// A pending, mandatory restore: once D-FLY is assigned, skipping restore
  /// leaves the rider without Rear Up/Down outdoors.
  bool get hasPendingRestore =>
      isDflyAssigned && core.settings.getShimanoBackup(_serialKey) != null;

  /// A GATT/handshake timeout means the Di2 didn't answer (asleep / out of
  /// range) — the sheet then prompts the rider to wake it and retry.
  bool _isUnresponsive(Object error) {
    if (error is TimeoutException) return true;
    if (error is ShimanoAuthException) return error.message.contains('TimeoutException');
    return false;
  }

  /// Authenticate → back up the ORIGINAL switch config to disk BEFORE any write
  /// → assign D-FLY channels so each paddle reports over the radio. The backup
  /// is captured once and never overwritten, so a re-run can't wipe the only
  /// copy of the rider's configuration.
  Future<void> setupControl() async {
    final t = _configTransport;
    if (t == null) return;
    try {
      await ShimanoConfig.authenticate(t);
      if (core.settings.getShimanoBackup(_serialKey) == null) {
        final backup = await ShimanoConfig.backup(t);
        await core.settings.setShimanoBackup(_serialKey, backup);
      }
      // Assign the two paddles of each shifter slot to distinct D-FLY channels
      // (slot 0 → Ch1/Ch2, slot 1 → Ch3/Ch4).
      final backup = core.settings.getShimanoBackup(_serialKey) ?? const {};
      const channels = [
        [ShimanoSwitchFunction.dflyCh1, ShimanoSwitchFunction.dflyCh2],
        [ShimanoSwitchFunction.dflyCh3, ShimanoSwitchFunction.dflyCh4],
      ];
      for (final slot in backup.keys) {
        final pair = channels[slot % channels.length];
        await ShimanoConfig.assignDfly(
          t,
          slot: slot,
          config: ShimanoSwitchConfig.fromFunctions(
            a: pair[0],
            b: pair[1],
            c: ShimanoSwitchFunction.none,
            s: ShimanoSwitchFunction.none,
          ),
        );
      }
      await core.settings.setShimanoDflyAssigned(_serialKey, true);
      core.connection.signalChange(this);
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('ShimanoDi2 setup failed: $e\n$st'));
      await recordError(e, st, context: 'ShimanoDi2: D-FLY setup');
      rethrow;
    }
  }

  /// Authenticate → replay the backed-up switch config byte-for-byte, restoring
  /// the rider's original shifting, then clear the pending-restore state.
  Future<void> restoreShifting() async {
    final t = _configTransport;
    final backup = core.settings.getShimanoBackup(_serialKey);
    if (t == null || backup == null) return;
    try {
      await ShimanoConfig.authenticate(t);
      await ShimanoConfig.restore(t, backup);
      await core.settings.setShimanoDflyAssigned(_serialKey, false);
      await core.settings.clearShimanoBackup(_serialKey);
      core.connection.signalChange(this);
    } catch (e, st) {
      actionStreamInternal.add(LogNotification('ShimanoDi2 restore failed: $e\n$st'));
      await recordError(e, st, context: 'ShimanoDi2: D-FLY restore');
      rethrow;
    }
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    if (hasConfigService) {
      return [
        shimanoSetupPanel(
          context,
          assigned: isDflyAssigned,
          hasBackup: core.settings.getShimanoBackup(_serialKey) != null,
          onSetup: () => unawaited(
            showShimanoSetup(context, operation: setupControl, isUnresponsive: _isUnresponsive),
          ),
          onRestore: () => unawaited(
            showShimanoRestore(context, operation: restoreShifting, isUnresponsive: _isUnresponsive),
          ),
        ),
      ];
    }
    return [
      Text(
        'Make sure to set your Di2 buttons to D-Fly channels in the Shimano E-TUBE app.',
        style: context.typography.xSmall.copyWith(color: Colors.grey),
      ),
    ];
  }
}

class ShimanoDi2Constants {
  static const String SERVICE_UUID = "000018ef-5348-494d-414e-4f5f424c4500";
  static const String SERVICE_UUID_ALTERNATIVE = "000018ff-5348-494d-414e-4f5f424c4500";

  static const String D_FLY_CHANNEL_UUID = "00002ac2-5348-494d-414e-4f5f424c4500";
}

enum _Di2State {
  shortPress,
  longPress,
  keep,
  doublePress,
  released,
}
