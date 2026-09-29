import 'package:bike_control/utils/window_size.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Grows a button to Android's 48×48 dp minimum touch target on phone-sized
/// windows.
///
/// shadcn's text buttons are 35–38 px tall on a phone (28–32 px at
/// `ButtonSize.small`) — fine for a mouse, small for a thumb on a bike. This
/// is for a screen's primary actions only, not a global restyle: dense inline
/// buttons and every desktop window keep shadcn's sizes.
class BkTouchTarget extends StatelessWidget {
  const BkTouchTarget({super.key, required this.child});

  /// Android's minimum touch target, in logical pixels.
  static const double minSize = 48;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isCompactWindow(context)) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: child,
    );
  }
}
