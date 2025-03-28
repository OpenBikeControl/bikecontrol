import 'package:flutter/foundation.dart';

/// Represents the manufacturer data of a BLE device.
class ManufacturerData {
  final int companyId;
  final Uint8List payload;
  ManufacturerData(this.companyId, this.payload);

  String get companyIdRadix16 => "0x0${companyId.toRadixString(16)}";

  factory ManufacturerData.fromData(Uint8List data) {
    if (data.length < 2) {
      throw const FormatException("Invalid Manufacturer Data");
    }
    return ManufacturerData(
      (data[0] + (data[1] << 8)),
      data.sublist(2),
    );
  }

  Uint8List toUint8List() {
    final byteData = ByteData(2);
    byteData.setInt16(0, companyId, Endian.host);
    return Uint8List.fromList(
      byteData.buffer.asUint8List() + payload.toList(),
    );
  }

  @override
  int get hashCode => companyId.hashCode ^ payload.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ManufacturerData) return false;
    return companyId == other.companyId && listEquals(payload, other.payload);
  }

  @override
  String toString() {
    return 'Manufacturer: $companyIdRadix16 - $payload';
  }
}
