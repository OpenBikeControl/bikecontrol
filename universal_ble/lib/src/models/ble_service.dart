import 'package:universal_ble/universal_ble.dart';

class BleService {
  late String uuid;
  List<BleCharacteristic> characteristics;

  BleService(String uuid, this.characteristics) {
    this.uuid = BleUuidParser.string(uuid);
  }

  @override
  String toString() {
    return 'BleService{uuid: $uuid, characteristics: $characteristics}';
  }
}

class BleCharacteristic {
  late String uuid;
  List<CharacteristicProperty> properties;

  BleCharacteristic(String uuid, this.properties) {
    this.uuid = BleUuidParser.string(uuid);
  }

  @override
  String toString() {
    return 'BleCharacteristic{uuid: $uuid, properties: $properties}';
  }
}

enum CharacteristicProperty {
  broadcast,
  read,
  writeWithoutResponse,
  write,
  notify,
  indicate,
  authenticatedSignedWrites,
  extendedProperties;

  const CharacteristicProperty();

  factory CharacteristicProperty.parse(int index) =>
      CharacteristicProperty.values[index];

  @override
  String toString() => name;
}
