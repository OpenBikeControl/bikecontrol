/// Why the advertised address looks like one the trainer app cannot reach.
///
/// The three call for different advice: a VPN or bridge wants turning off,
/// mobile data wants the trainer app's Wi-Fi, two real networks want the rider
/// to check which one the app is on. Its own file so the home card's input
/// model can carry it without pulling in the probes.
enum AddressWarningKind {
  /// The pick is a tunnel, bridge or other virtual adapter.
  unreachable,

  /// The pick is on mobile data: this device is not on Wi-Fi at all.
  noWifi,

  /// The pick is fine, but a second real network could be the app's.
  twoNetworks,
}
