import 'package:flutter/material.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:swift_control/widgets/ui/colors.dart';

class CustomFrame extends StatelessWidget {
  const CustomFrame({
    super.key,
    required this.title,
    required this.device,
    this.frameColors,
    required this.child,
    required this.platform,
  });

  final TargetPlatform platform;
  final String title;
  final ScreenshotDevice device;
  final ScreenshotFrameColors? frameColors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 8),
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
                    borderRadius: BorderRadius.circular(64),
                  ),
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(width: 8),
                    borderRadius: BorderRadius.circular(64),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: switch (platform) {
                    TargetPlatform.android => ScreenshotFrame.androidPhone(device: device, child: child),
                    TargetPlatform.fuchsia => throw UnimplementedError(),
                    TargetPlatform.iOS => ScreenshotFrame.iphone(device: device, child: child),
                    TargetPlatform.linux => throw UnimplementedError(),
                    TargetPlatform.macOS => ScreenshotFrame.noFrame(device: device, child: child),
                    TargetPlatform.windows => ScreenshotFrame.noFrame(device: device, child: child),
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
