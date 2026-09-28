import 'package:flutter/semantics.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void buildToast({
  LogLevel level = LogLevel.LOGLEVEL_INFO,
  String? title,
  Widget? titleWidget,
  String closeTitle = 'Close',
  // Top-right: footer action bars (wizard Continue, settings saves) live at
  // the bottom — toasts must never cover them.
  ToastLocation location = ToastLocation.topRight,
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  if (navigatorKey.currentContext?.mounted ?? false) {
    _announce(navigatorKey.currentContext!, level: level, title: title, subtitle: subtitle);
    // Desktop: top-right (footers live bottom-right there). Mobile: normal
    // bottom placement — lifted above the wizard's sticky footer only while
    // onboarding is active.
    final isMobile = MediaQuery.sizeOf(navigatorKey.currentContext!).width < 600;
    showToast(
      context: navigatorKey.currentContext!,
      location: isMobile
          ? (onboardingActive ? ToastLocation.bottomCenter : ToastLocation.bottomRight)
          : location,
      showDuration: switch (level) {
        LogLevel.LOGLEVEL_DEBUG => const Duration(seconds: 2),
        LogLevel.LOGLEVEL_INFO => duration ?? const Duration(seconds: 3),
        LogLevel.LOGLEVEL_WARNING => duration ?? const Duration(seconds: 5),
        LogLevel.LOGLEVEL_ERROR => duration ?? const Duration(seconds: 7),
        _ => duration ?? const Duration(seconds: 3),
      },
      builder: (context, overlay) => Padding(
        padding: EdgeInsets.only(bottom: onboardingActive && MediaQuery.sizeOf(context).width < 600 ? 72 : 0),
        child: SurfaceCard(
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
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 100),
                      child: Text(closeTitle),
                    ),
                  ),
            trailingAlignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

/// Toasts are visual only; screen readers need the same message spoken.
/// Errors interrupt (assertive), everything else waits its turn (polite).
void _announce(BuildContext context, {required LogLevel level, String? title, String? subtitle}) {
  final message = [title, subtitle].whereType<String>().where((s) => s.trim().isNotEmpty).join('. ');
  if (message.isEmpty) return;
  final view = View.maybeOf(context);
  if (view == null) return;
  SemanticsService.sendAnnouncement(
    view,
    message,
    Directionality.maybeOf(context) ?? TextDirection.ltr,
    assertiveness: level == LogLevel.LOGLEVEL_ERROR ? Assertiveness.assertive : Assertiveness.polite,
  );
}
