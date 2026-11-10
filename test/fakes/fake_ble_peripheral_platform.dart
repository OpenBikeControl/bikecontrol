import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
// PeripheralService (the pigeon-level service model the platform interface
// receives) is not re-exported by the public library.
// ignore: implementation_imports
import 'package:universal_ble/src/universal_ble.g.dart' show PeripheralService;
import 'package:universal_ble/universal_ble.dart';

/// In-memory implementation of universal_ble's peripheral role. The test acts
/// as the BLE central (a trainer app on e.g. Apple TV): it can subscribe to
/// characteristics, write to them, and observes the notifications BikeControl
/// sends. Install via `UniversalBlePeripheral.setInstance(fake)`.
class FakeUniversalBlePeripheralPlatform extends UniversalBlePeripheralPlatform {
  final services = <PeripheralService>[];

  /// When true, [startAdvertising] always fails as if the native GATT map were
  /// empty — models a peripheral stuck in a bad state where re-registering the
  /// services doesn't take, so recovery retries keep failing.
  bool rejectAllAdvertising = false;
  bool advertising = false;
  String? advertisedLocalName;
  List<String> advertisedServices = [];

  OnPeripheralReadRequest? _readHandler;
  OnPeripheralWriteRequest? _writeHandler;

  /// Notifications pushed by the app, in order.
  final notificationsSent = <({String characteristicId, Uint8List value, String? deviceId})>[];

  /// charId (lowercase) -> subscribed central device ids.
  final subscribers = <String, Set<String>>{};

  void reset() {
    services.clear();
    advertising = false;
    advertisedLocalName = null;
    advertisedServices = [];
    notificationsSent.clear();
    subscribers.clear();
  }

  // ── Central-side test helpers ─────────────────────────────────────────────

  /// Simulate a central subscribing to notifications on [characteristicId].
  void centralSubscribe(String deviceId, String characteristicId) {
    final uuid = characteristicId.toLowerCase();
    (subscribers[uuid] ??= {}).add(deviceId);
    updateCharacteristicSubscription(
      BlePeripheralCharacteristicSubscriptionChanged(
        deviceId: deviceId,
        characteristicId: uuid,
        isSubscribed: true,
        name: 'FakeCentral',
      ),
    );
  }

  /// Simulate a central unsubscribing.
  void centralUnsubscribe(String deviceId, String characteristicId) {
    final uuid = characteristicId.toLowerCase();
    subscribers[uuid]?.remove(deviceId);
    updateCharacteristicSubscription(
      BlePeripheralCharacteristicSubscriptionChanged(
        deviceId: deviceId,
        characteristicId: uuid,
        isSubscribed: false,
        name: 'FakeCentral',
      ),
    );
  }

  /// Simulate a central writing to a characteristic.
  PeripheralWriteRequestResult? centralWrite(String deviceId, String characteristicId, List<int> value) =>
      _writeHandler?.call(deviceId, characteristicId.toLowerCase(), 0, Uint8List.fromList(value));

  /// Simulate a central reading a characteristic.
  PeripheralReadRequestResult? centralRead(String deviceId, String characteristicId) =>
      _readHandler?.call(deviceId, characteristicId.toLowerCase(), 0, null);

  // ── UniversalBlePeripheralPlatform implementation ────────────────────────

  @override
  void setReadRequestHandler(OnPeripheralReadRequest? handler) => _readHandler = handler;

  @override
  void setWriteRequestHandler(OnPeripheralWriteRequest? handler) => _writeHandler = handler;

  @override
  void setDescriptorReadRequestHandler(OnPeripheralDescriptorReadRequest? handler) {}

  @override
  void setDescriptorWriteRequestHandler(OnPeripheralDescriptorWriteRequest? handler) {}

  @override
  Future<PeripheralReadinessState> getAvailabilityState() async => PeripheralReadinessState.ready;

  @override
  Future<PeripheralAdvertisingState> getAdvertisingState() async =>
      advertising ? PeripheralAdvertisingState.advertising : PeripheralAdvertisingState.idle;

  @override
  Future<BlePeripheralCapabilities> getCapabilities() async => const BlePeripheralCapabilities(
    supportsPeripheralMode: true,
    supportsManufacturerDataInAdvertisement: true,
    supportsManufacturerDataInScanResponse: true,
    supportsServiceDataInAdvertisement: true,
    supportsServiceDataInScanResponse: true,
    supportsTargetedCharacteristicUpdate: true,
    supportsAdvertisingTimeout: true,
  );

  @override
  Future<void> addService(PeripheralService service, {Duration? timeout}) async {
    services.add(service);
    updateServiceAdded(BlePeripheralServiceAdded(service.uuid, null));
  }

  @override
  Future<void> removeService(String serviceId) async {
    services.removeWhere((s) => s.uuid.toLowerCase() == serviceId.toLowerCase());
  }

  @override
  Future<void> clearServices() async => services.clear();

  @override
  Future<List<String>> getServices() async => services.map((s) => s.uuid).toList();

  @override
  Future<void> startAdvertising({
    required List<String> services,
    String? localName,
    Duration? timeout,
    ManufacturerData? manufacturerData,
    PeripheralPlatformConfig? platformConfig,
  }) async {
    // Mirror the Windows native plugin: advertising with no registered GATT
    // services fails with PlatformException(failed, "No services added to
    // advertise") — regardless of the requested `services` argument. A
    // process-global clearServices() between addService and here reproduces it.
    if (rejectAllAdvertising || this.services.isEmpty) {
      throw PlatformException(code: 'failed', message: 'No services added to advertise');
    }
    advertising = true;
    advertisedLocalName = localName;
    advertisedServices = services;
    updateAdvertisingState(BlePeripheralAdvertisingStateChanged(PeripheralAdvertisingState.advertising, null));
  }

  @override
  Future<void> stopAdvertising() async {
    advertising = false;
    updateAdvertisingState(BlePeripheralAdvertisingStateChanged(PeripheralAdvertisingState.idle, null));
  }

  @override
  Future<void> updateCharacteristicValue({
    required String characteristicId,
    required Uint8List value,
    String? deviceId,
  }) async {
    notificationsSent.add((characteristicId: characteristicId.toLowerCase(), value: value, deviceId: deviceId));
  }

  @override
  Future<List<String>> getSubscribedClients(String characteristicId) async =>
      subscribers[characteristicId.toLowerCase()]?.toList() ?? [];

  @override
  Future<int?> getMaximumNotifyLength(String deviceId) async => 512;
}
