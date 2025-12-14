import 'package:flutter/material.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:bike_control/widgets/ui/colors.dart';

import 'screenshot_test.dart';

class CustomFrame extends StatelessWidget {
  const CustomFrame({
    super.key,
    required this.title,
    required this.device,
    this.frameColors,
    required this.child,
    required this.platform,
  });

  final DeviceType platform;
  final String title;
  final ScreenshotDevice device;
  final ScreenshotFrameColors? frameColors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadiusValue = 26.0;
    return platform == DeviceType.noFrame
        ? Scaffold(body: child)
        : Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BKColor.main, BKColor.mainEnd],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 16),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 170,
                    left: 8,
                    right: 8,
                    bottom: -30,
                    child: FittedBox(
                      child: Container(
                        width: device.resolution.width / device.pixelRatio,
                        height: device.resolution.height / device.pixelRatio,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(borderRadiusValue),
                        ),
                        foregroundDecoration: BoxDecoration(
                          border: Border.all(width: 8),
                          borderRadius: BorderRadius.circular(borderRadiusValue),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: switch (platform) {
                          DeviceType.android => ScreenshotFrame.androidPhone(device: device, child: child),
                          DeviceType.androidTablet => ScreenshotFrame.androidTablet(device: device, child: child),
                          DeviceType.iPhone => ScreenshotFrame.iphone(device: device, child: child),
                          DeviceType.iPad => ScreenshotFrame.ipad(device: device, child: child),
                          DeviceType.desktop => ScreenshotFrame.noFrame(device: device, child: child),
                          DeviceType.noFrame => throw UnimplementedError(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
