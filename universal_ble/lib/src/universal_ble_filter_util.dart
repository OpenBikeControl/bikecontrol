import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

// A default Filter on dart side
// Used on Linux only
class UniversalBleFilterUtil {
  ScanFilter? scanFilter;

  bool matchesDevice(BleDevice device) {
    final filter = scanFilter;
    if (filter == null) return true;

    final hasNamePrefixFilter = filter.withNamePrefix.isNotEmpty;
    final hasServiceFilter = filter.withServices.isNotEmpty;
    final hasManufacturerDataFilter = filter.withManufacturerData.isNotEmpty;

    // If there is no filter at all, then allow device
    if (!hasNamePrefixFilter &&
        !hasServiceFilter &&
        !hasManufacturerDataFilter) {
      return true;
    }

    // Else check one of the filter passes
    return hasNamePrefixFilter && nameMatches(filter, device) ||
        hasServiceFilter && servicesMatch(filter, device) ||
        hasManufacturerDataFilter && manufacturerDataMatches(filter, device);
  }

  bool nameMatches(ScanFilter scanFilter, BleDevice device) {
    var namePrefixFilter = scanFilter.withNamePrefix;
    if (namePrefixFilter.isEmpty) return true;

    String? name = device.name;
    if (name == null || name.isEmpty) return false;
    return namePrefixFilter.any(name.startsWith);
  }

  bool servicesMatch(ScanFilter scanFilter, BleDevice device) {
    var serviceFilters = scanFilter.withServices;
    if (serviceFilters.isEmpty) return true;

    List<String> serviceUuids = device.services;
    if (serviceUuids.isEmpty) {
      return false;
    }
    return serviceFilters.any(serviceUuids.contains);
  }

  bool manufacturerDataMatches(ScanFilter scanFilter, BleDevice device) {
    final manufacturerDataFilters = scanFilter.withManufacturerData;
    if (manufacturerDataFilters.isEmpty) return true;

    List<ManufacturerData> deviceDataList = device.manufacturerDataList;
    if (deviceDataList.isEmpty) return false;

    return deviceDataList
        .any((deviceData) => manufacturerDataFilters.any((filter) {
              // Early return if company identifiers don't match
              if (filter.companyIdentifier != deviceData.companyId) {
                return false;
              }

              final payloadPrefix = filter.payloadPrefix;
              final payload = deviceData.payload;

              // Handle cases where payload prefix is null or empty
              if (payloadPrefix == null || payloadPrefix.isEmpty) {
                return true;
              }

              // Validate payload lengths
              if (payload.isEmpty || payloadPrefix.length > payload.length) {
                return false;
              }

              final filterMask = filter.payloadMask;

              // Choose comparison strategy based on filter mask
              return filterMask != null &&
                      filterMask.length == payloadPrefix.length
                  ? _compareWithMask(payloadPrefix, payload, filterMask)
                  : _compareWithoutMask(payloadPrefix, payload);
            }));
  }

  bool _compareWithMask(Uint8List prefix, Uint8List payload, Uint8List mask) {
    for (int i = 0; i < prefix.length; i++) {
      if ((prefix[i] & mask[i]) != (payload[i] & mask[i])) {
        return false;
      }
    }
    return true;
  }

  bool _compareWithoutMask(Uint8List prefix, Uint8List payload) {
    for (int i = 0; i < prefix.length; i++) {
      if (prefix[i] != payload[i]) {
        return false;
      }
    }
    return true;
  }
}
