import 'dart:async';
import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:prop/prop.dart';
import 'package:universal_ble/universal_ble.dart';

/// A non-timeout GATT failure from [ShimanoBleTransport], annotated with the
/// operation and characteristic that failed so a diagnostics line says what
/// broke (`… (read 00002af4-…)`). The original error stays in [cause].
/// Mirrors `SramTransportException`.
class ShimanoTransportException implements Exception {
  ShimanoTransportException(this.operation, this.characteristic, this.cause);

  final String operation;
  final String characteristic;
  final Object cause;

  @override
  String toString() => '$cause ($operation $characteristic)';
}

/// `universal_ble`-backed [ShimanoTransport]. Notifications/indications flow
/// through the app's existing pipeline; the owning device calls
/// [onNotification] from its `processCharacteristic` callback.
///
/// Every GATT call rethrows its failure with the operation and characteristic
/// attached. A [TimeoutException] stays a [TimeoutException] (with the context
/// appended); anything else is wrapped in a [ShimanoTransportException].
/// Mirrors `SramBleTransport`.
class ShimanoBleTransport implements ShimanoTransport {
  ShimanoBleTransport(this.deviceId, this.services);

  final String deviceId;
  final List<BleService> services;

  final Map<String, StreamController<Uint8List>> _controllers = {};

  StreamController<Uint8List> _ctrl(String characteristic) => _controllers.putIfAbsent(
        characteristic.toLowerCase(),
        () => StreamController<Uint8List>.broadcast(),
      );

  void onNotification(String characteristic, Uint8List value) =>
      _ctrl(characteristic).add(value);

  String? _serviceFor(String characteristic) => services
      .firstOrNullWhere((s) => s.characteristics.any((c) => c.uuid == characteristic.toLowerCase()))
      ?.uuid;

  Future<T> _withContext<T>(String operation, String characteristic, Future<T> Function() call) async {
    try {
      return await call();
    } on TimeoutException catch (e, st) {
      final message = '${e.message ?? 'timed out'} ($operation $characteristic)';
      Error.throwWithStackTrace(TimeoutException(message, e.duration), st);
    } catch (e, st) {
      Error.throwWithStackTrace(ShimanoTransportException(operation, characteristic, e), st);
    }
  }

  @override
  Future<void> subscribe(String characteristic) async {
    final char = characteristic.toLowerCase();
    final service = _serviceFor(char);
    if (service == null) return;
    await _withContext('subscribe', char, () async {
      // 2AF3 (auth control) indicates; the PCE response char notifies.
      if (char == ShimanoDi2Config.authControlChar.toLowerCase()) {
        await UniversalBle.subscribeIndications(deviceId, service, char);
      } else {
        await UniversalBle.subscribeNotifications(deviceId, service, char);
      }
    });
  }

  @override
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false}) async {
    final char = characteristic.toLowerCase();
    final service = _serviceFor(char);
    if (service == null) throw StateError('Shimano: no service for $characteristic');
    await _withContext(
      'write',
      char,
      () => UniversalBle.write(deviceId, service, char, data, withoutResponse: withoutResponse),
    );
  }

  @override
  Future<Uint8List> read(String characteristic) async {
    final char = characteristic.toLowerCase();
    final service = _serviceFor(char);
    if (service == null) throw StateError('Shimano: no service for $characteristic');
    return _withContext('read', char, () => UniversalBle.read(deviceId, service, char));
  }

  @override
  Stream<Uint8List> notifications(String characteristic) => _ctrl(characteristic).stream;
}
