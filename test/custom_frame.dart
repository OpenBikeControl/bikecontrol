import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/material.dart';
import 'package:golden_screenshot/golden_screenshot.dart';

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
    final headerHeight =
        [DeviceType.androidTablet, DeviceType.iPad, DeviceType.desktop].contains(platform) ? 120.0 : 170.0;
    final logicalWidth = device.resolution.width / device.pixelRatio;
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
                  // Title sits in the band above the device frame and shrinks to
                  // fit, so long localized titles never overlap the frame.
                  Positioned(
                    top: 30,
                    left: 16,
                    right: 16,
                    height: headerHeight - 38,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: logicalWidth - 32,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: headerHeight,
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
