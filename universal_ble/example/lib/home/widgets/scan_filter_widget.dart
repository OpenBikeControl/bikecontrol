import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/widgets/platform_button.dart';

class ScanFilterWidget extends StatefulWidget {
  final Function(ScanFilter? filter) onScanFilter;
  final TextEditingController servicesFilterController;
  final TextEditingController namePrefixController;
  final TextEditingController manufacturerDataController;

  const ScanFilterWidget({
    super.key,
    required this.onScanFilter,
    required this.servicesFilterController,
    required this.namePrefixController,
    required this.manufacturerDataController,
  });

  @override
  State<ScanFilterWidget> createState() => _ScanFilterWidgetState();
}

class _ScanFilterWidgetState extends State<ScanFilterWidget> {
  String? error;

  void applyFilter() {
    setState(() {
      error = null;
    });
    try {
      List<String> serviceUUids = [];
      List<String> namePrefixes = [];
      List<ManufacturerDataFilter> manufacturerDataFilters = [];

      // Parse Services
      if (widget.servicesFilterController.text.isNotEmpty) {
        List<String> services = widget.servicesFilterController.text.split(',');
        for (String service in services) {
          try {
            serviceUUids.add(BleUuidParser.string(service.trim()));
          } on FormatException catch (_) {
            throw Exception("Invalid Service UUID $service");
          }
        }
      }

      // Parse Name Prefix
      String namePrefix = widget.namePrefixController.text;
      if (namePrefix.isNotEmpty) {
        namePrefixes = namePrefix.split(',').map((e) => e.trim()).toList();
      }

      // Parse Manufacturer Data
      String manufacturerDataText = widget.manufacturerDataController.text;
      if (manufacturerDataText.isNotEmpty) {
        List<String> manufacturerData = manufacturerDataText.split(',');
        for (String manufacturer in manufacturerData) {
          int? companyIdentifier = int.tryParse(manufacturer);
          if (companyIdentifier == null) {
            throw Exception("Invalid Manufacturer Data $manufacturer");
          }
          manufacturerDataFilters.add(
              ManufacturerDataFilter(companyIdentifier: companyIdentifier));
        }
      }

      if (serviceUUids.isEmpty &&
          namePrefixes.isEmpty &&
          manufacturerDataFilters.isEmpty) {
        widget.onScanFilter(null);
      } else {
        widget.onScanFilter(
          ScanFilter(
            withServices: serviceUUids,
            withNamePrefix: namePrefixes,
            withManufacturerData: manufacturerDataFilters,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Filters Applied")),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  void clearFilter() {
    widget.servicesFilterController.clear();
    widget.namePrefixController.clear();
    widget.manufacturerDataController.clear();
    widget.onScanFilter(null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.copyWith(left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              "Scan Filters",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Text("Use comma to add multiple values"),
          const Divider(),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.namePrefixController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Name Prefixes",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.servicesFilterController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Services",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.manufacturerDataController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Manufacturer Data Company IDs",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: PlatformButton(
                  text: 'Apply',
                  onPressed: applyFilter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlatformButton(
                  text: 'Clear',
                  onPressed: clearFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
