enum AvailabilityState {
  unknown,
  resetting,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn;

  const AvailabilityState();

  factory AvailabilityState.parse(int index) => AvailabilityState.values[index];
}
