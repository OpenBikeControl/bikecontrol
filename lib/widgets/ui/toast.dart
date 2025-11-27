import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';

Widget buildToast(
  BuildContext context,
  ToastOverlay overlay, {
  LogLevel level = LogLevel.LOGLEVEL_INFO,
  String? title,
  Widget? titleWidget,
  String closeTitle = 'Close',
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  return SurfaceCard(
    duration: switch (level) {
      LogLevel.LOGLEVEL_DEBUG => const Duration(seconds: 2),
      LogLevel.LOGLEVEL_INFO => const Duration(seconds: 3),
      LogLevel.LOGLEVEL_WARNING => const Duration(seconds: 5),
      LogLevel.LOGLEVEL_ERROR => const Duration(seconds: 7),
      _ => duration ?? const Duration(seconds: 3),
    },
    filled: true,
    fillColor: switch (level) {
      LogLevel.LOGLEVEL_DEBUG => null,
      LogLevel.LOGLEVEL_INFO => null,
      LogLevel.LOGLEVEL_WARNING => Theme.of(context).colorScheme.accent,
      LogLevel.LOGLEVEL_ERROR => Theme.of(context).colorScheme.destructive,
      _ => null,
    },
    child: Basic(
      title: titleWidget ?? Text(title ?? ''),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: PrimaryButton(
        size: ButtonSize.small,
        onPressed: () {
          // Close the toast programmatically when clicking Undo.
          overlay.close();
          onClose?.call();
        },
        child: Text(closeTitle),
      ),
      trailingAlignment: Alignment.center,
    ),
  );
}
