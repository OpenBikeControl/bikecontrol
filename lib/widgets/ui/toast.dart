import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';

void buildToast(
  BuildContext context, {
  LogLevel level = LogLevel.LOGLEVEL_INFO,
  String? title,
  Widget? titleWidget,
  String closeTitle = 'Close',
  ToastLocation location = ToastLocation.bottomRight,
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  showToast(
    context: context,
    location: location,
    showDuration: switch (level) {
      LogLevel.LOGLEVEL_DEBUG => const Duration(seconds: 2),
      LogLevel.LOGLEVEL_INFO => const Duration(seconds: 3),
      LogLevel.LOGLEVEL_WARNING => const Duration(seconds: 5),
      LogLevel.LOGLEVEL_ERROR => const Duration(seconds: 7),
      _ => duration ?? const Duration(seconds: 3),
    },
    builder: (context, overlay) => SurfaceCard(
      filled: switch (level) {
        LogLevel.LOGLEVEL_WARNING => true,
        LogLevel.LOGLEVEL_ERROR => true,
        _ => false,
      },
      fillColor: switch (level) {
        LogLevel.LOGLEVEL_DEBUG => null,
        LogLevel.LOGLEVEL_INFO => null,
        LogLevel.LOGLEVEL_WARNING => Theme.of(context).colorScheme.chart1,
        LogLevel.LOGLEVEL_ERROR => Theme.of(context).colorScheme.destructive,
        _ => null,
      },
      child: Basic(
        title: titleWidget ?? Text(title ?? ''),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: titleWidget is ButtonWidget
            ? null
            : PrimaryButton(
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
    ),
  );
}
