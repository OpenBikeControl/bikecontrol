import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

class ServicesListWidget extends StatelessWidget {
  final List<BleService> discoveredServices;
  final bool scrollable;
  final Function(BleService service, BleCharacteristic characteristic)? onTap;

  const ServicesListWidget({
    super.key,
    required this.discoveredServices,
    this.onTap,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      itemCount: discoveredServices.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            child: ExpandablePanel(
              header: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward_ios),
                    Expanded(child: Text(discoveredServices[index].uuid)),
                  ],
                ),
              ),
              collapsed: const SizedBox(),
              expanded: Column(
                children: discoveredServices[index]
                    .characteristics
                    .map((e) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  onTap?.call(discoveredServices[index], e);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.arrow_right_outlined),
                                        Expanded(child: Text(e.uuid)),
                                      ],
                                    ),
                                    Text(
                                      "Properties: ${e.properties.map((e) => e.name)}",
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
