import 'dart:async';

import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

/// The startup splash's mark: the brand disc the native launch screen shows
/// (flutter_native_splash.yaml), the same image at the same size in the same
/// place, so the hand-off from the native screen to Flutter doesn't move.
/// Only if startup takes a while does a spinner fade in under it.
class LaunchMark extends StatefulWidget {
  const LaunchMark({super.key});

  /// BkBrandMark at 4x; the native launch screens are generated from it too.
  static const String asset = 'assets/splash/splash.png';

  /// The disc on screen, in logical pixels: the native screens' 128 dp/pt.
  static const double size = 128;

  /// A quick start never shows the spinner.
  static const Duration spinnerDelay = Duration(milliseconds: 700);

  /// Decodes [asset] into the image cache, so the first frame can draw it.
  /// Completes once decoded, on error, or after [timeout], whichever is first.
  static Future<void> precache({Duration timeout = const Duration(milliseconds: 300)}) {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final stream = const AssetImage(asset).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((_, _) => finish(), onError: (_, _) => finish());
    stream.addListener(listener);
    return done.future
        .timeout(timeout, onTimeout: () {})
        .whenComplete(() => stream.removeListener(listener));
  }

  @override
  State<LaunchMark> createState() => _LaunchMarkState();
}

class _LaunchMarkState extends State<LaunchMark> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LaunchMark.spinnerDelay, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Centred on the whole window, as the native screens centre it.
        Image.asset(
          LaunchMark.asset,
          key: const ValueKey('launch-mark'),
          width: LaunchMark.size,
          height: LaunchMark.size,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
        Transform.translate(
          offset: const Offset(0, LaunchMark.size / 2 + 48),
          child: AnimatedOpacity(
            opacity: _slow ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: const SizedBox.square(
              dimension: 24,
              child: m.CircularProgressIndicator(strokeWidth: 2.4, color: BKColor.main),
            ),
          ),
        ),
      ],
    );
  }
}
