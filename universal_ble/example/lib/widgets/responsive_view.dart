import 'package:flutter/material.dart';

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

class ResponsiveView extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;
  const ResponsiveView({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return builder(
          ctx,
          constraints.maxWidth > 1000
              ? DeviceType.desktop
              : constraints.maxWidth > 600 && constraints.maxWidth < 1000
                  ? DeviceType.tablet
                  : DeviceType.mobile,
        );
      },
    );
  }
}
