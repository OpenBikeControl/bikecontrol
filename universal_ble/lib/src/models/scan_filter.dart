import 'package:universal_ble/src/models/manufacturer_data_filter.dart';

class ScanFilter {
  List<String> withServices;
  List<ManufacturerDataFilter> withManufacturerData;
  List<String> withNamePrefix;

  ScanFilter({
    this.withServices = const [],
    this.withManufacturerData = const [],
    this.withNamePrefix = const [],
  });

  @override
  String toString() {
    return 'ScanFilter(withServices: $withServices, withManufacturerData: $withManufacturerData, withNamePrefix: $withNamePrefix)';
  }
}
