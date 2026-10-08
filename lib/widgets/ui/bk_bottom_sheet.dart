import 'package:bike_control/widgets/ui/sheet_pull_to_dismiss.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A sheet from the bottom of the screen that comes down the way it went up:
/// a drag handle on top, and a swipe down — on the handle, or past the top of
/// scrolling content ([SheetPullToDismiss]) — closes it. shadcn's `openSheet`
/// has neither, which on a phone leaves only the barrier to tap.
///
/// Close it from inside with `closeDrawer` (or `closeSheet`, the same thing).
Future<T?> openBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
}) {
  return openDrawer<T>(
    context: context,
    position: OverlayPosition.bottom,
    constraints: constraints,
    builder: (sheetContext) => SheetPullToDismiss(child: builder(sheetContext)),
  );
}
