enum BleInputProperty {
  disabled,
  notification,
  indication;

  const BleInputProperty();

  factory BleInputProperty.parse(int index) => BleInputProperty.values[index];
}

enum BleOutputProperty {
  withResponse,
  withoutResponse;

  const BleOutputProperty();

  factory BleOutputProperty.parse(int index) => BleOutputProperty.values[index];
}
