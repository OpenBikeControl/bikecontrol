import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shows a transient message in the app's toast layer (see [BkToastTheme]).
///
/// On a phone it sits bottom-centre above the tab bar; on wider windows
/// bottom-right, in the content area. [closeTitle] turns the close control
/// into a text action ("Undo", "Open") that runs [onClose]; without it the
/// toast has a small close button, which runs [onClose] too.
void buildToast({
  LogLevel level = LogLevel.LOGLEVEL_INFO,
  String? title,
  Widget? titleWidget,
  String? closeTitle,
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  showBkToast(
    context,
    level: level,
    title: title,
    titleWidget: titleWidget,
    closeTitle: closeTitle,
    onClose: onClose,
    subtitle: subtitle,
    duration: duration,
  );
}

/// [buildToast] from an explicit [context]: the toast goes to the nearest
/// [ToastLayer] above it. For captures and tests without the app's navigator.
void showBkToast(
  BuildContext context, {
  LogLevel level = LogLevel.LOGLEVEL_INFO,
  String? title,
  Widget? titleWidget,
  String? closeTitle,
  VoidCallback? onClose,
  String? subtitle,
  Duration? duration,
}) {
  _announce(context, level: level, title: title, subtitle: subtitle);
  final compact = isCompactWindow(context);
  showToast(
    context: context,
    location: compact ? ToastLocation.bottomCenter : ToastLocation.bottomRight,
    entryDuration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 400),
    showDuration: switch (level) {
      LogLevel.LOGLEVEL_DEBUG => const Duration(seconds: 2),
      LogLevel.LOGLEVEL_INFO => duration ?? const Duration(seconds: 3),
      LogLevel.LOGLEVEL_WARNING => duration ?? const Duration(seconds: 5),
      LogLevel.LOGLEVEL_ERROR => duration ?? const Duration(seconds: 7),
      _ => duration ?? const Duration(seconds: 3),
    },
    builder: (context, overlay) => Padding(
      // Onboarding has no tab bar, but a sticky footer the toast must clear.
      padding: EdgeInsets.only(bottom: onboardingActive && isCompactWindow(context) ? 72 : 0),
      child: BkToastCard(
        level: level,
        title: titleWidget ?? Text(title ?? ''),
        body: subtitle,
        // A row of controller buttons is the whole message; it closes itself.
        showClose: titleWidget is! ButtonWidget,
        actionLabel: closeTitle,
        onAction: () {
          overlay.close();
          onClose?.call();
        },
      ),
    ),
  );
}

/// How far app chrome along the bottom edge — the phone's tab bar — reaches
/// above the bottom safe area. [BkToastTheme] keeps toasts above it.
final ValueNotifier<double> toastBottomClearance = ValueNotifier(0);

/// Where the app's toasts sit, for every [ToastLayer] below it — shadcn's
/// root layer above the navigator included, which is where [buildToast]
/// shows them. On a phone they sit bottom-centre, as wide as the window less
/// 16 a side and 8 above the tab bar ([toastBottomClearance]); from 600 wide
/// they sit bottom-right, 24 in from the side and 8 above the tab bar — or,
/// from 840, 24 in from the corner, clear of the sidebar.
///
/// Goes ABOVE the `ShadcnApp`: the root layer lives inside it.
class BkToastTheme extends StatelessWidget {
  const BkToastTheme({super.key, required this.child, this.scaling});

  final Widget child;

  /// The size scaling the app theme applies (ToastLayer multiplies its
  /// padding by it). Defaults to [BkTheme.scaling]'s.
  final double? scaling;

  /// Width of a toast from 600 wide.
  static const double wideWidth = 380;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Breakpoints.compact;
    final scale = scaling ?? BkTheme.scaling.sizeScaling;
    return ValueListenableBuilder<double>(
      valueListenable: toastBottomClearance,
      builder: (context, clearance, child) => ComponentTheme<ToastTheme>(
        data: ToastTheme(
          padding: compact
              ? EdgeInsets.fromLTRB(16, 16, 16, clearance + 8) / scale
              // Below 840 the tab bar runs along the bottom: 8 above it.
              : EdgeInsets.fromLTRB(16, 16, 24, clearance > 0 ? clearance + 8 : 24) / scale,
          toastConstraints: BoxConstraints.tightFor(
            width: compact ? math.max(0, width - 32) : math.min(wideWidth, width - 48),
          ),
        ),
        child: child!,
      ),
      child: child,
    );
  }
}

/// Reports its child's height above the bottom safe area as
/// [toastBottomClearance] while it is laid out, and zero once it is gone.
class ReportsToastClearance extends SingleChildRenderObjectWidget {
  const ReportsToastClearance({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderToastClearance(MediaQuery.paddingOf(context).bottom);

  @override
  void updateRenderObject(BuildContext context, RenderToastClearance renderObject) {
    renderObject.safeBottom = MediaQuery.paddingOf(context).bottom;
  }
}

class RenderToastClearance extends RenderProxyBox {
  RenderToastClearance(this._safeBottom);

  double _safeBottom;
  set safeBottom(double value) {
    if (value == _safeBottom) return;
    _safeBottom = value;
    markNeedsLayout();
  }

  static void _publish(double value) {
    // Never mid-layout: the toast layer rebuilds on the change.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (toastBottomClearance.value != value) toastBottomClearance.value = value;
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void performLayout() {
    super.performLayout();
    final clearance = math.max(0.0, size.height - _safeBottom);
    if (clearance != toastBottomClearance.value) _publish(clearance);
  }

  @override
  void detach() {
    super.detach();
    _publish(0);
  }
}

/// A toast in the card language: the card surface, 16 px corners, the status
/// icon leading, the title over an optional body, and an accent text action
/// or a small close button. A soft shadow lifts it off whatever it floats
/// over.
class BkToastCard extends StatelessWidget {
  const BkToastCard({
    super.key,
    required this.level,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.showClose = true,
  });

  final LogLevel level;
  final Widget title;
  final String? body;

  /// Shown as an accent text button; runs [onAction]. Without it, the close
  /// button runs [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final status = BkStatusColors.of(context);
    final (IconData icon, Color tone) = switch (level) {
      LogLevel.LOGLEVEL_ERROR => (LucideIcons.circleAlert, status.danger),
      LogLevel.LOGLEVEL_WARNING => (LucideIcons.triangleAlert, status.warning),
      LogLevel.LOGLEVEL_DEBUG => (LucideIcons.info, cs.mutedForeground),
      _ => (LucideIcons.info, bkAccentText(context)),
    };
    final action = actionLabel;

    return Container(
      // Dark: one step above the cards it floats over. Light: a white card.
      decoration: BoxDecoration(
        color: dark ? cs.popover : cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        border: dark ? Border.all(color: bkStrongBorder(context).withValues(alpha: 0.35), width: 0.5) : null,
        boxShadow: [
          BoxShadow(
            color: cs.foreground.withValues(alpha: dark ? 0.0 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: dark ? 0.45 : 0.06),
            blurRadius: dark ? 20 : 4,
            offset: Offset(0, dark ? 8 : 1),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(14, 10, showClose || action != null ? 4 : 14, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tone),
          const Gap(12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  DefaultTextStyle.merge(
                    style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                    child: title,
                  ),
                  if (body case final body? when body.isNotEmpty)
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                    ),
                ],
              ),
            ),
          ),
          if (action != null) ...[
            const Gap(4),
            BkTouchTarget(
              child: Button.ghost(
                alignment: Alignment.center,
                style: const ButtonStyle.ghost(size: ButtonSize.small),
                onPressed: onAction,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: bkAccentText(context),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (showClose)
            BkIconButton.ghost(
              icon: Icon(LucideIcons.x, size: 16, color: cs.mutedForeground),
              label: AppLocalizations.of(context).close,
              onPressed: onAction,
            ),
        ],
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
