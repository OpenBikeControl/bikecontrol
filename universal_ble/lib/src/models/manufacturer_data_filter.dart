import 'dart:typed_data';

class ManufacturerDataFilter {
  /// Must be of integer type, in hex or decimal form (e.g. 0x004c or 76).
  int companyIdentifier;

  /// Matches as prefix the peripheral's advertised data.
  Uint8List? payloadPrefix;

  /// For each bit in the mask, set it to 1 if it needs to match
  /// the corresponding one in manufacturer data, or otherwise set it to 0.
  /// The 'mask' must have the same length as the payload.
  Uint8List? payloadMask;

  /// Filter manufacturer data by company identifier, payload prefix, or payload mask.
  ManufacturerDataFilter({
    required this.companyIdentifier,
    this.payloadPrefix,
    this.payloadMask,
  });

  @override
  String toString() {
    return 'ManufacturerDataFilter(companyIdentifier: $companyIdentifier, payloadPrefix: $payloadPrefix, mask: $payloadMask)';
  }
}
