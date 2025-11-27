import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget buildToast(
  BuildContext context,
  ToastOverlay overlay, {
  required String title,
  String closeTitle = 'Close',
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  return SurfaceCard(
    duration: duration,
    child: Basic(
      title: Text(title),
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
