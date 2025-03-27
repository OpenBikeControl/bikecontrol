part of 'windows.dart';

class BluetoothCharacteristicWindows extends BluetoothCharacteristic {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid? secondaryServiceUuid;
  final Guid characteristicUuid;
  final List<BluetoothDescriptor> descriptors;

  final Properties propertiesWinBle;

  BluetoothCharacteristicWindows({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.descriptors,
    required this.propertiesWinBle,
    this.secondaryServiceUuid,
  }) : super.fromProto(
          BmBluetoothCharacteristic(
            remoteId: DeviceIdentifier(remoteId.str),
            serviceUuid: serviceUuid,
            characteristicUuid: characteristicUuid,
            descriptors: [
              for (final descriptor in descriptors)
                BmBluetoothDescriptor(
                  remoteId: DeviceIdentifier(descriptor.remoteId.str),
                  serviceUuid: descriptor.serviceUuid,
                  characteristicUuid: descriptor.characteristicUuid,
                  descriptorUuid: descriptor.uuid,
                  primaryServiceUuid: null, // TODO:  API changes
                ),
            ],
            properties: BmCharacteristicProperties(
              broadcast: propertiesWinBle.broadcast ?? false,
              read: propertiesWinBle.read ?? false,
              writeWithoutResponse: propertiesWinBle.writeWithoutResponse ?? false,
              write: propertiesWinBle.write ?? false,
              notify: propertiesWinBle.notify ?? false,
              indicate: propertiesWinBle.indicate ?? false,
              authenticatedSignedWrites: propertiesWinBle.authenticatedSignedWrites ?? false,
              // TODO: implementation missing
              extendedProperties: false,
              // TODO: implementation missing
              notifyEncryptionRequired: false,
              // TODO: implementation missing
              indicateEncryptionRequired: false,
            ),
            primaryServiceUuid: null, // TODO:  API changes
          ),
        );

  String get _address => remoteId.str.toLowerCase();

  String get _key => "$serviceUuid:$characteristicUuid";

  FBP.BluetoothDevice get device =>
      FlutterBluePlusWindows.connectedDevices.firstWhere((device) => device.remoteId == remoteId);

  /// this variable is updated:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (if subscribed)
  List<int> get lastValue => FlutterBluePlusWindows._lastChrs[remoteId]?[_key] ?? [];

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - anytime a notification arrives (if subscribed)
  ///   - and when first listened to, it re-emits the last value for convenience
  Stream<List<int>> get lastValueStream => _mergeStreams(
        [
          WinBle.characteristicValueStreamOf(
            address: _address,
            serviceId: serviceUuid.str128,
            characteristicId: characteristicUuid.str128,
          ),
          FlutterBluePlusWindows._charReadWriteStream.where((e) => e.$1 == _key).map((e) => e.$2)
        ],
      ).map((p) => <int>[...p]).newStreamWithInitialValue(lastValue).asBroadcastStream();

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime a notification arrives (if subscribed)
  Stream<List<int>> get onValueReceived => _mergeStreams(
        [
          WinBle.characteristicValueStreamOf(
            address: _address,
            serviceId: serviceUuid.str128,
            characteristicId: characteristicUuid.str128,
          ),
          FlutterBluePlusWindows._charReadStream.where((e) => e.$1 == _key).map((e) => e.$2)
        ],
      ).map((p) => <int>[...p]).asBroadcastStream();

  // TODO: need to verify
  bool get isNotifying => FlutterBluePlusWindows._isNotifying[remoteId]?[_key] ?? false;

  Future<List<int>> read({int timeout = 15}) async {
    final value = await WinBle.read(
      address: _address,
      serviceId: serviceUuid.str128,
      characteristicId: characteristicUuid.str128,
    );
    FlutterBluePlusWindows._charReadWriteStreamController.add((_key, value));
    FlutterBluePlusWindows._charReadStreamController.add((_key, value));
    FlutterBluePlusWindows._lastChrs[remoteId] ??= {};
    FlutterBluePlusWindows._lastChrs[remoteId]?[_key] = value;
    return value;
  }

  Future<void> write(List<int> value,
      {bool allowLongWrite = false, bool withoutResponse = false, int timeout = 15}) async {
    await WinBle.write(
      address: _address,
      service: serviceUuid.str128,
      characteristic: characteristicUuid.str128,
      data: Uint8List.fromList(value),
      writeWithResponse: !withoutResponse, // propertiesWinBle.writeWithoutResponse ?? false,
    );
    FlutterBluePlusWindows._charReadWriteStreamController.add((_key, value));
    FlutterBluePlusWindows._lastChrs[remoteId] ??= {};
    FlutterBluePlusWindows._lastChrs[remoteId]?[_key] = value;
  }

  // TODO: need to verify
  Future<bool> setNotifyValue(
    bool notify, {
    int timeout = 15, // TODO: missing implementation
    bool forceIndications = false, // TODO: missing implementation
  }) async {
    /// unSubscribeFromCharacteristic
    try {
      await WinBle.unSubscribeFromCharacteristic(
        address: _address,
        serviceId: serviceUuid.str128,
        characteristicId: characteristicUuid.str128,
      );
    } catch (e) {
      log('WinBle.unSubscribeFromCharacteristic was performed '
          'before setNotifyValue()');
    }

    /// set notify
    try {
      if (notify) {
        await WinBle.subscribeToCharacteristic(
          address: _address,
          serviceId: serviceUuid.str128,
          characteristicId: characteristicUuid.str128,
        );
      }
      FlutterBluePlusWindows._isNotifying[remoteId] ??= {};
      FlutterBluePlusWindows._isNotifying[remoteId]?[_key] = notify;
    } catch (e) {
      log(e.toString());
    }
    return true;
  }
}
